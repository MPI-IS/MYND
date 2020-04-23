//
//  StorageController.swift
//  myndios
//
//  Created by Matthias Hohmann on 20.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import RxSwift
import Foundation
import HDF5Kit
import ResearchKit
import SwiftyJSON

/// The `StorageController` stores files to the document directory of the application, optionally with encryption. All storage functions return an index at which the `DataModel` representation for this file was stored in user-defaults. This representation is the only way to retrieve, manipulate, transmit, or delete the stored file. Storage occurs right after the subject completes the corresponding task.
class StorageController: NSObject {
    
    static let shared = StorageController()
    
    let defaults = UserDefaults.standard
    let nc = NotificationCenter.default
    
    /////////////////////////
    // MARK: - Data Storage
    
    /**
     Store an EEG recording as HDF5 on disk
     - File contains Recording, Paradigm, and MetaData
     
     Returns index at which the file was stored
     
     The `EEGrecording` object is defined in `RecordingDelegate`. See the example recording in supplemental files and the exemplary load function for more details on the HDF5 file structure.
     */
    func storeRecording(_ recording: EEGRecording) -> Int {
        let session = recording.subjectInfo["sessionID"] as! Int
        let run = recording.subjectInfo["runID"] as! Int
        let uuid = recording.subjectInfo["subjectID"] as! String
        let channels = recording.subjectInfo["channelNames"] as! [String]
        let day = recording.subjectInfo["day"] as? Int ?? 0
        let name = recording.paradigm?.title
        
        var fileName = ("r_\(name ?? "noName")_\(day)_\(session)_\(run)_\(uuid).hdf")
        guard let h5file = File.create(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + fileName, mode: .truncate) else {
            nc.postBanner(message: "Could not create file!", style: "devError")
            return -1
        }
        
        do {
            // Date Storage
            let group = h5file.createGroup("Recording")
            // Add ChannelNames
            try group.createStringDataset("ChannelNames", dataspace: Dataspace(dims: [1, channels.count], maxDims: [1, channels.count]))?.write(channels)
            // Add Raw Data
            let dims: [Int] = [recording.rawData.count,recording.rawData[0].count]
            try _ = group.createAndWriteDataset("Data", dims: dims, data: recording.rawData.flatMap({$0}))
            // Add Marker Channel and Timestamps
            try _ = group.createAndWriteDataset("Marker", dims: [recording.markerData.count, 1], data: recording.markerData)
            try _ = group.createAndWriteDataset("TimeStamp", dims: [recording.timeStamp.count, 1], data: recording.timeStamp)
            // Add Any Attribute as String from Dictionary
            for element in recording.subjectInfo {
                try _ = group.createStringAttribute("\(element.key)")?.write("\(element.value)")
            }
            // Add global stats
            try _ = group.createIntAttribute("Session", dataspace: Dataspace(dims: [1,1]))?.write([session])
            try _ = group.createIntAttribute("Run", dataspace: Dataspace(dims: [1,1]))?.write([run])
            try _ = group.createIntAttribute("Version", dataspace: Dataspace(dims: [1,1]))?.write([3])
            
            // Add trialinfo if exists
            if !recording.trialInfo.isEmpty {
                try _ = group.createStringDataset("Trials", dataspace: Dataspace(dims: [1, recording.trialInfo.count], maxDims: [1, recording.trialInfo.count]))?.write(recording.trialInfo.map({$0.0}))
                try _ = group.createAndWriteDataset("Points", dims: [1, recording.trialInfo.count], data: recording.trialInfo.map({$0.1}))
            }
            
            // Paradigm Storage
            if let paradigm = recording.paradigm {
                let paradigmGroup = h5file.createGroup("Paradigm")
                try _ = paradigmGroup.createStringAttribute("Paradigm")?.write((paradigm.title))
                try _ = paradigmGroup.createStringDataset("ConditionLabels", dataspace: Dataspace(dims: [1, paradigm.conditionCount]))?.write(paradigm.conditionLabels)
                try _ = paradigmGroup.createAndWriteDataset("ConditionMarkers", dims: [1, paradigm.conditionCount], data: paradigm.conditionMarkers)
                try _ = paradigmGroup.createAndWriteDataset("BaseMarkers", dims: [1, paradigm.conditionCount], data: paradigm.baseMarkers)
                try _ = paradigmGroup.createIntAttribute("BaseTime", dataspace: Dataspace(dims: [1,1]))?.write([paradigm.baseTime])
                try _ = paradigmGroup.createIntAttribute("TrialTime", dataspace: Dataspace(dims: [1,1]))?.write([paradigm.trialTime])
                try _ = paradigmGroup.createIntAttribute("ConditionCount", dataspace: Dataspace(dims: [1,1]))?.write([paradigm.conditionCount])
            }
        } catch {
            nc.postBanner(message: "Could not write to file!", style: "devError")
            return -1
        }
        
        h5file.flush()
        
        // if data should be encrypted during storage, the file is replaced with an encrypted version here.
        if defaults.bool(forKey: "encryptDuringStorage") && defaults.bool(forKey: "isEncryptionEnabled") {
            encryptDuringStorage(fileName: &fileName)
        }
        
        return addFileToDatabase(type: .recording, session: session, runid: String(run), fileName: fileName)
    }
    
    /**
     Store a Consent PDF to disk. To store the Consent PDF the *ResearchKit* object `ORKTaskResult` is passed at the end of the boarding procedure, together with the `StudyModel` object of the boarded study. The PDF is regenerated from the steps defined in `StudyModel.consent` and the signature is applied to it. It is then stored.
     
     Returns true if stored successfully
     */
    func storeConsent(of study: StudyModel, withResult result: ORKTaskResult, completion: @escaping (()->())) {
        let uuid = defaults.string(forKey: "uuid")
        
        if let stepResult = result.stepResult(forStepIdentifier: "ConsentReviewStep") {
            
            for result in stepResult.results! {
                
                if let signatureResult = result as? ORKConsentSignatureResult {
                    // Only proceed if consented
                    if signatureResult.consented && (study.consent.document != nil),
                        let document = study.consent.document?.copy() as? ORKConsentDocument {
                        signatureResult.apply(to: document)
                        document.makePDF() { [weak self] (data, error) -> Void in
                            guard let strongSelf = self else {return}
                            // We store the PDF here and add it to our file database
                            var fileName = ("\(study.study.rawValue)_consent_\(uuid ?? "").pdf")
                            let filePath = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName))!
                            do {
                                try data?.write(to: filePath)
                                // if data should be encrypted during storage, the file is replaced with an encrypted version here.
                                if strongSelf.defaults.bool(forKey: "encryptDuringStorage") && strongSelf.defaults.bool(forKey: "isEncryptionEnabled") {
                                    strongSelf.encryptDuringStorage(fileName: &fileName)
                                }
                            }
                            catch {
                                strongSelf.nc.postBanner(message: "Could not store PDF!", style: "devError")
                                completion()
                            }
                            
                            _ = strongSelf.addFileToDatabase(type: .consent, session: 0, runid: "", fileName: fileName)
                            completion()
                        }
                    }
                }
                
            }
        }
    }
    
    /// To store a questionnaire, a `String:Any` dictionary is passed and stored as JSON.
    func storeQuestionnaire(_ answers: [String: Any]) -> Int {
        
        let json = JSON(answers)
        guard json.rawString() != nil else {return -1}
        
        var fileName = ("q_\(json["title"].string!)_\(json["day"].int!)_\(json["sessionID"].int!)_\(json["runID"].int!)_\(json["subjectID"].string!).json")
        let filePath = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName))!
        do {
            try json.rawData(options: .prettyPrinted).write(to: filePath)
            // if data should be encrypted during storage, the file is replaced with an encrypted version here.
            if defaults.bool(forKey: "encryptDuringStorage") && defaults.bool(forKey: "isEncryptionEnabled") {
                encryptDuringStorage(fileName: &fileName)
            }
        }
        catch {
            nc.postBanner(message: "Could not store JSON!", style: "devError")
            return -1
        }
                
        return self.addFileToDatabase(type: .consent, session: 0, runid: "", fileName: fileName)
    }
    
    
    
    /**
     Append stored file to database
     
     Returns index at which the file was stored
     */
    func addFileToDatabase(type: FileTypes, session: Int, runid: String, fileName: String) -> Int {
        let defaults = UserDefaults.standard
        var storedData = defaults.array(forKey: "storedData") as! [Dictionary<String, Any>]
        storedData.append(DataModel(type: type, date: Date(), session: session, uuid: defaults.string(forKey: "uuid")!, runid: runid, fileName: fileName).asDictionary())
        defaults.set(storedData, forKey: "storedData")
        let index = storedData.endIndex - 1
        return index
    }
    
    /// data encryption
    func encryptDuringStorage( fileName: inout String) {
        let filePath = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName))!
        do {
            let file = try Data(contentsOf: filePath)
            guard let encryptedFile = EncryptionController.shared.encryptData(file) else {fatalError("Cannot encrypt data")}
            try encryptedFile.write(to: filePath.appendingPathExtension("asc"))
            // delete the unencrypted file
            try FileManager.default.removeItem(at: filePath)
            fileName += ".asc"
        }
        catch let error {
            fatalError("Error encrypting file: \(error.localizedDescription)")
        }
    }
    
    /////////////////////////
    // MARK: - Data Deletion
    /////////////////////////
    
    /**
     Erase file at a specified index (optional)
     - Attention: If no index is supplied, all data will be erased
     - Returns true if successful
     */
    func eraseData(atIndex index: Int? = nil) -> Bool {
        let fileManager = FileManager.default
        var storedData = [DataModel]()
        for item in defaults.array(forKey: "storedData") as! [Dictionary<String, Any>] {
            storedData.append(DataModel.init(withDict: item))
        }
        
        if index == nil {
            for (_,item) in storedData.enumerated() {
                do {
                    let dir = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first)?.appendingPathComponent(item.fileName)
                    try fileManager.removeItem(at: dir!)
                }
                catch {
                    self.nc.postBanner(message: "Could not remove file at \(item.fileName)", style: "devError")
                    return false
                }
            }
            storedData.isEmpty ? defaults.set([Dictionary<String, Any>](), forKey: "storedData") : ()
            return true
        } else {
            let dir = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first)?.appendingPathComponent(storedData[index!].fileName)
            do {
                try fileManager.removeItem(at: dir!)
                storedData.remove(at: index!)
                defaults.set(storedData.map{$0.asDictionary()}, forKey: "storedData")
            }
            catch {
                self.nc.postBanner(message: "Could not remove file at \(storedData[index!].fileName)", style: "devError")
                return false
            }
            return true
        }
    }
}
