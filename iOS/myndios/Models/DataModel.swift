//
//  DataModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 28.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import Foundation

enum FileTypes: String {
    case recording
    case questionnaire
    case consent
}

/**
 This model is used to describe the created data in the system. File paths and some meta information are stored as dictionary entry in the user settings. Later on, they can be retrieved and manipulated if the file is deleted or transmitted. The object contains functions to convert informtation from and to dictionary format for storage.
 */
class DataModel: NSObject {
    
    let type: FileTypes
    let date: Date
    let session: Int
    let uuid: String
    let runid: String
    var stored: Bool
    var transmitted: Bool
    
    let fileName: String
    
    init(type: FileTypes, date: Date, session: Int, uuid: String, runid: String, fileName: String) {
        self.type = type
        self.date = date
        self.session = session
        self.uuid = uuid
        self.runid = runid
        self.stored = true
        self.transmitted = false
        
        self.fileName = fileName
    }
    
    init(withDict dict: Dictionary<String, Any>) {
        self.type = FileTypes(rawValue: dict["type"] as! String)! //this is necessary as enums are not hashable
        self.date = dict["date"] as! Date
        self.session = dict["session"] as! Int
        self.uuid = dict["uuid"] as! String
        self.runid = dict["runid"] as! String
        self.stored = dict["stored"] as! Bool
        self.transmitted = dict["transmitted"] as! Bool
        
        self.fileName = dict["fileName"] as! String
    }
    
    func asDictionary() -> Dictionary<String, Any> {
        let dict: [String: Any] = [
        "type": String(describing: self.type), //this is necessary as enums are not hashable
        "date": self.date,
        "session": self.session,
        "uuid": self.uuid,
        "runid": self.runid,
        "stored": self.stored,
        "transmitted": self.transmitted,
        
        "fileName": self.fileName,
        ]
        return dict
    }
    
}
