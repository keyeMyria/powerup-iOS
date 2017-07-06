enum DatabaseError: Error {
    case databaseInitFailed
    case databaseQueryFailed
    case databaseUpdateFailed
}

/** This is a singleton class for acessing SQLite Database. */
class DatabaseAccessor {
    
    // Database file name
    private let DatabaseName = "mainDatabase"
    private let DatabaseFileType = "sqlite"
    
    // TODO: Multiple avatars with different IDs.
    let avatarID = 1
    
    // The instance of DatabaseAccessor
    static let sharedInstance = DatabaseAccessor()
    
    // The instance of the SQLite database
    private var mainDB: FMDatabase?
    
    // Private initializer to avoid instancing by other classes
    private init() {}
    
    /**
      Open and initialize the database. Should be called once the app starts.
     */
    public func initializeDatabase() throws {
        // File directory.
        let fileManager = FileManager.default
        let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        let databasePath = (dirPath as NSString).appendingPathComponent(DatabaseName + "." + DatabaseFileType) as NSString
        
        // Database not existing, create one.
        if !fileManager.fileExists(atPath: databasePath as String) {
            if let bundlePath = Bundle.main.path(forResource: DatabaseName, ofType: DatabaseFileType) {
                try fileManager.copyItem(atPath: bundlePath, toPath: databasePath as String)
            }
        }
        
        mainDB = FMDatabase(path: databasePath as String)
        
        if mainDB == nil || !((mainDB?.open())!) {
            throw DatabaseError.databaseInitFailed
        }
    }
    
    /**
      Get the questions of a scenario from the database.
      
      - Parameter: The scenario ID.
      - Return: A dictionary of [QuestionID -> Question].
    */
    public func getQuestions(of scenarioID: Int) throws -> [Int:Question] {
        let queryString = "SELECT * FROM Question WHERE ScenarioID = \(scenarioID)"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        var result = [Int:Question]()
        
        // Loop through all the results of questions
        while queryResults?.next() == true {
            if let questionID = queryResults?.int(forColumn: "QuestionID"), let scenarioID = queryResults?.int(forColumn: "ScenarioID"), let questionDescription = queryResults?.string(forColumn: "QDescription") {
                
                result[Int(questionID)] = Question(questionID: Int(questionID), questionDescription: questionDescription, scenarioID: Int(scenarioID))
            } else {
                throw DatabaseError.databaseQueryFailed
            }
        }
        
        return result
    }
    
    /**
      Get the answers (choices) of a question from the database.
 
      - Parameter: The QuestionID.
      - Return: An array of answers, sorted by their answerID.
    */
    public func getAnswers(of questionID: Int) throws -> [Answer] {
        let queryString = "SELECT * FROM Answer WHERE QuestionID = \(questionID) ORDER BY AnswerID"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        var result = [Answer]()
        
        // Loop through all the results of choices
        while queryResults?.next() == true {
            if let answerID = queryResults?.int(forColumn: "AnswerID"), let questionID = queryResults?.int(forColumn: "QuestionID"), let answerDescription = queryResults?.string(forColumn: "ADescription"), let nextQuestionID = queryResults?.string(forColumn: "NextQID"), let points = queryResults?.int(forColumn: "Points") {
                
                result.append(Answer(answerID: Int(answerID), questionID: Int(questionID), answerDescription: answerDescription, nextQuestionID: nextQuestionID, points: Int(points)))
                
            } else {
                throw DatabaseError.databaseQueryFailed
            }
        }
        
        return result
    }
    
    /**
      Save the accessories of the avatar in the database.
      
      - Parameter: An avatar class.
    */
    public func saveAvatar(_ avatar: Avatar) throws {
        // Determine whether they are nil, if they are, set its string to "NULL"
        let necklaceString = avatar.necklace == nil ? "NULL" : String(avatar.necklace!.id)
        let glassesString = avatar.glasses == nil ? "NULL" : String(avatar.glasses!.id)
        let handbagString = avatar.handbag == nil ? "NULL" : String(avatar.handbag!.id)
        let hatString = avatar.hat == nil ? "NULL" : String(avatar.hat!.id)
        
        // Set the query string.
        let queryString = "UPDATE Avatar SET \(AccessoryType.face.rawValue)=\(avatar.face.id), \(AccessoryType.clothes.rawValue)=\(avatar.clothes.id), \(AccessoryType.hair.rawValue)=\(avatar.hair.id), \(AccessoryType.eyes.rawValue)=\(avatar.eyes.id), \(AccessoryType.necklace.rawValue)=" + necklaceString + ", \(AccessoryType.glasses.rawValue)=" + glassesString + ", \(AccessoryType.handbag.rawValue)=" + handbagString + ", \(AccessoryType.hat.rawValue)=" + hatString + " WHERE ID = \(avatarID)"
        
        // Execute update query.
        guard mainDB!.executeUpdate(queryString, withArgumentsIn: nil) else {
            throw DatabaseError.databaseUpdateFailed
        }
    }
    
    /**
      Get the saved avatar from the database.
    
      - Return: A saved avatar stored in database.
    */
    public func getAvatar() throws -> Avatar {
        let queryString = "SELECT * FROM Avatar WHERE ID = \(avatarID)"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        var result = Avatar()
        
        // Get the results.
        if queryResults?.next() == true {
            
            // Face
            let faceID = Int(queryResults!.int(forColumn: AccessoryType.face.rawValue))
            let face = try getAccessory(accessoryType: .face, accessoryIndex: faceID)
            
            // Clothes
            let clothesID = Int(queryResults!.int(forColumn: AccessoryType.clothes.rawValue))
            let clothes = try getAccessory(accessoryType: .clothes, accessoryIndex: clothesID)
            
            // Hair
            let hairID = Int(queryResults!.int(forColumn: AccessoryType.hair.rawValue))
            let hair = try getAccessory(accessoryType: .hair, accessoryIndex: hairID)
            
            // Eyes
            let eyesID = Int(queryResults!.int(forColumn: AccessoryType.eyes.rawValue))
            let eyes = try getAccessory(accessoryType: .eyes, accessoryIndex: eyesID)
            
            // Necklace (optional)
            let necklaceID: Int? = (queryResults!.isNull(forColumn: AccessoryType.necklace.rawValue) ? nil : Int(queryResults!.int(forColumn: AccessoryType.necklace.rawValue)))
            let necklace: Accessory? = necklaceID == nil ? nil : try getAccessory(accessoryType: .necklace, accessoryIndex: necklaceID!)
            
            // Glasses (optional)
            let glassesID: Int? = (queryResults!.isNull(forColumn: AccessoryType.glasses.rawValue) ? nil : Int(queryResults!.int(forColumn: AccessoryType.glasses.rawValue)))
            let glasses: Accessory? = glassesID == nil ? nil : try getAccessory(accessoryType: .glasses, accessoryIndex: glassesID!)
            
            // Handbag (optional)
            let handbagID: Int? = (queryResults!.isNull(forColumn: AccessoryType.handbag.rawValue) ? nil : Int(queryResults!.int(forColumn: AccessoryType.handbag.rawValue)))
            let handbag: Accessory? = handbagID == nil ? nil : try getAccessory(accessoryType: .handbag, accessoryIndex: handbagID!)
            
            // Hat (optional)
            let hatID: Int? = (queryResults!.isNull(forColumn: AccessoryType.hat.rawValue) ? nil : Int(queryResults!.int(forColumn: AccessoryType.hat.rawValue)))
            let hat: Accessory? = hatID == nil ? nil : try getAccessory(accessoryType: .hat, accessoryIndex: hatID!)
            
            // Init avatar
            result = Avatar(avatarID: avatarID, face: face, eyes: eyes, hair: hair, clothes: clothes, necklace: necklace, glasses: glasses, handbag: handbag, hat: hat)
            
        } else {
            throw DatabaseError.databaseQueryFailed
        }
        
        return result
    }
    
    /** 
      Get an array of accessories of a type.
      - Parameter: Accessory type (i.e. Hair, Face, etc.).
      - Return: An array of accessories.
    */
    public func getAccessoryArray(accessoryType: AccessoryType) -> [Accessory] {
        let queryString = "SELECT * FROM " + accessoryType.rawValue + " ORDER BY ID"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        var result = [Accessory]()
        
        while queryResults?.next() == true {
            let accessoryID = Int(queryResults!.int(forColumn: "ID"))
            let accessoryImageName = queryResults!.string(forColumn: "Name")
            let accessoryPoints = Int(queryResults!.int(forColumn: "Points"))
            let accessoryPurchased = queryResults!.bool(forColumn: "Purchased")
            
            let currAccessory = Accessory(type: accessoryType, id: accessoryID, imageName: accessoryImageName!, points: accessoryPoints, purchased: accessoryPurchased)
            
            result.append(currAccessory)
        }
        
        return result
    }
    
    /**
      Get an accessory by a given accessory type and index.
      - Parameter: index.
      - Return: The corresponding accessories.
    */
    public func getAccessory(accessoryType: AccessoryType, accessoryIndex: Int) throws -> Accessory {
        let queryString = "SELECT * FROM " + accessoryType.rawValue + " WHERE ID = \(accessoryIndex)"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        var result: Accessory!
        
        if queryResults?.next() == true {
            let accessoryID = Int(queryResults!.int(forColumn: "ID"))
            let accessoryImageName = queryResults!.string(forColumn: "Name")
            let accessoryPoints = Int(queryResults!.int(forColumn: "Points"))
            let accessoryPurchased: Bool = Int(queryResults!.int(forColumn: "Purchased")) == 1
            
            result = Accessory(type: accessoryType, id: accessoryID, imageName: accessoryImageName!, points: accessoryPoints, purchased: accessoryPurchased)
        } else {
            throw DatabaseError.databaseQueryFailed
        }
        
        return result
    }
    
    /**
      Set the accessory as bought in the database.
      - Parameter: The accessory intended to be saved.
    */
    public func boughtAccessory(accessory: Accessory) throws {
        let queryString = "UPDATE \(accessory.type.rawValue) SET Purchased = 1 WHERE ID = \(accessory.id)"
        
        guard mainDB!.executeUpdate(queryString, withArgumentsIn: nil) else {
            throw DatabaseError.databaseUpdateFailed
        }
    }

    /**
      Create a new entry into the Avatar table.
      - Parameter: Face, clothes, hair, eyes.
    */
    public func createAvatar(_ avatar: Avatar) throws {
        
        // Reset database (so the previous purchased accessories will be restored to unpurchased).
        try resetDatabase()
        
        // Avatar already exists, use update instead of insert.
        if avatarExists() {
            
            // Update avatar
            try saveAvatar(avatar)
            
            // Reset scores.
            let updateQuery = "UPDATE Score SET Strength = 0, Invisibility = 0, Healing = 0, Telepathy = 0, Points = 0 WHERE ID = \(avatarID)"
            
            guard mainDB!.executeUpdate(updateQuery, withArgumentsIn: nil) else {
                throw DatabaseError.databaseUpdateFailed
            }
            
            return
        }
        
        // Necklace, glasses, handbag, hat are NULL because players cannot have those when creating new avatars.
        let queryString = "INSERT INTO Avatar (ID, Face, Clothes, Hair, Eyes, Necklace, Glasses, Handbag, Hat) VALUES (\(avatarID), \(avatar.face.id), \(avatar.clothes.id), \(avatar.hair.id), \(avatar.eyes.id), NULL, NULL, NULL, NULL)"
        
        guard mainDB!.executeUpdate(queryString, withArgumentsIn: nil) else {
            throw DatabaseError.databaseUpdateFailed
        }
        
        // Create an entry for score, storing the points and powers for the avatar.
        let insertQuery = "INSERT INTO Score (ID, Strength, Invisibility, Healing, Telepathy, Points) VALUES (\(avatarID), 0, 0, 0, 0, 0)"
        
        guard mainDB!.executeUpdate(insertQuery, withArgumentsIn: nil) else {
            throw DatabaseError.databaseUpdateFailed
        }
    }
    
    /**
      Check if an avatar is already created.
      - Return: Bool, true if there exist an avatar.
    */
    public func avatarExists() -> Bool {
        let queryString = "SELECT * FROM Avatar WHERE ID = \(avatarID)"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        return queryResults?.next() ?? false
    }
    
    /**
      Save the Karma points and the powers in the database.
      - Parameter: The score intended to save.
    */
    public func saveScore(score: Score) throws {
        let queryString = "UPDATE Score SET Strength = \(score.strength), Invisibility = \(score.invisibility), Healing = \(score.healing), Telepathy = \(score.telepathy), Points = \(score.karmaPoints) WHERE ID = \(avatarID)"
        
        guard mainDB!.executeUpdate(queryString, withArgumentsIn: nil) else {
            throw DatabaseError.databaseUpdateFailed
        }
    }
    
    /**
      Get the Karma points and the powers from the database.
      - Return: The points and powers in a Score struct.
    */
    public func getScore() throws -> Score {
        let queryString = "SELECT * FROM Score WHERE ID = \(avatarID)"
        let queryResults: FMResultSet? = mainDB?.executeQuery(queryString, withArgumentsIn: nil)
        
        if queryResults?.next() == true {
            let karmaPoint = Int(queryResults!.int(forColumn: "Points"))
            let strength = Int(queryResults!.int(forColumn: "Strength"))
            let invisibility = Int(queryResults!.int(forColumn: "Invisibility"))
            let healing = Int(queryResults!.int(forColumn: "Healing"))
            let telepathy = Int(queryResults!.int(forColumn: "Telepathy"))
            
            return Score(karmaPoints: karmaPoint, healing: healing, strength: strength, telepathy: telepathy, invisibility: invisibility)
        } else {
            throw DatabaseError.databaseQueryFailed
        }
    }
    
    /** Close database if it's opened */
    public func closeDatabase() {
        mainDB?.close()
    }
    
    /** Return if the database is initialized. */
    public func databaseIsInitialized() -> Bool {
        return mainDB != nil
    }
    
    /** Reset the data of the database. */
    public func resetDatabase() throws {
        
        mainDB?.close()
        
        // File directory.
        let fileManager = FileManager.default
        let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        let databasePath = (dirPath as NSString).appendingPathComponent(DatabaseName + "." + DatabaseFileType) as NSString
        
        // Check if the database exists
        if fileManager.fileExists(atPath: databasePath as String) {
            
            // Remove the old database.
            do {
                try fileManager.removeItem(atPath: databasePath as String)
            } catch let error as NSError {
                print(error)
            }
            
            // Replace the old database with a new one (from the app bundle).
            if let bundlePath = Bundle.main.path(forResource: DatabaseName, ofType: DatabaseFileType) {
                do {
                    try fileManager.copyItem(atPath: bundlePath, toPath: databasePath as String)
                } catch let error as NSError {
                    print(error)
                }
            }
        }
        
        mainDB = FMDatabase(path: databasePath as String)
        
        if mainDB == nil || !((mainDB?.open())!) {
            throw DatabaseError.databaseInitFailed
        }
    }
}
