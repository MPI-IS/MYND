//
//  TransferController.swift
//  myndios
//
//  Created by Matthias Hohmann on 25.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation
import SystemConfiguration
import FilesProvider
import SwiftyJSON
import KeychainSwift

enum TransferStates {
    case started
    case completed
    case error
}

protocol TransferControllerDelegate {
    func transferController(_ transferController: TransferController, didUpdateProgressTo progress: Float)
    func transferController(_ transferController: TransferController, didUpdateStateTo state: TransferStates, withMessage message: String)
}

/**
 Transmission is handled by the `TransferController`. It occurs automatically after storing data (can be changed in `Setup`). A visual representation of the upload progress is given with the `UploadViewController` after the subject completed a questionnaire or a recording. The `uploadpending` function can be called at any time to transfer pending items. The `DataModel` for each file contains a `transmission` flag that is set to true if transmission was successful.
 */
class TransferController: NSObject {
    
    static let shared = TransferController()
    
    private let defaults = UserDefaults.standard
    private let nc = NotificationCenter.default
    private let keychain = KeychainSwift()
    
    var delegate: TransferControllerDelegate?
    
    var smtpSession: MCOSMTPSession! = nil
    var webDav: WebDAVFileProvider! = nil
    var downloadWebDav: WebDAVFileProvider! = nil
    
    private var max: Float = 0.0
    private var progress: Float = 0.0
    
    override init() {
        super.init()
        initWebDav()
        initEmail()
    }
    
    /// the variables in here are set in `Setup`
    func initWebDav() {

        // upload webDav
        let baseURL = URL(string: keychain.get("cred_webdavupload")!)!
        let user = keychain.get("cred_userupload")!
        let pw = keychain.get("cred_passwordupload")!
        
        let credentials = URLCredential(user: user, password: pw, persistence: .permanent)
        webDav = WebDAVFileProvider(baseURL: baseURL, credential: credentials)
        
        
        // download webDav for technical support messages and updates
        let dbaseURL = URL(string: keychain.get("cred_webdavdownload")!)!
        let duser = keychain.get("cred_userdownload")!
        let dpw = keychain.get("cred_passworddownload")!
        
        let dcredentials = URLCredential(user: duser, password: dpw, persistence: .permanent)
        downloadWebDav = WebDAVFileProvider(baseURL: dbaseURL, credential: dcredentials)
    }
    
    /// function that adds a visual representation of the file transfer, used in `UploadView`
    func transferData(atIndices indices: [Int], completion: (()->())? = nil ) {
        
        // If transfer is disabled, return immediately
        if !defaults.bool(forKey: "isTransferEnabled") {
            delegate?.transferController(self, didUpdateStateTo: .completed, withMessage: NSLocalizedString("#transferDisabled#", comment: ""))
            completion?()
            return
        }
        
        // Also return immediately if we are not reachable via WiFi
        if currentReachabilityStatus != .reachableViaWiFi {
            delegate?.transferController(self, didUpdateStateTo: .error, withMessage: NSLocalizedString("#transferFailed#", comment: ""))
            return
        }
        
        // set the max progress to the amount of files that are supposed to be transferred, reset progress
        max = Float(indices.count)
        progress = 0.0
        delegate?.transferController(self, didUpdateProgressTo: progress)
        
        // try to upload the data via WebDav. If desired, send an encrypted e-mail if this fails.
        uploadData(atIndices: indices, emailData: defaults.bool(forKey: "emailData"), completion: completion)
        
    }
    
    /// this is the default function for sending data. If any error is encountered during the process and the option was enabled, the file will be sent as an e-mail instead. Otherwise, the app will do nothing.
    func uploadData(atIndices indices: [Int], emailData: Bool = false, completion: (()->())? = nil) {
        
        let folder = defaults.string(forKey: "uuid")!
        webDav == nil ? (initWebDav()) : ()
        
        // check if folder exists
        webDav?.contentsOfDirectory(path: folder)
        {_, error in
            // if folder does not exist, create one and rerun this function
            if error != nil {
                print("Error checking folder: \(error!.localizedDescription), trying to create one")
                self.webDav?.create(folder: folder, at: "/")
                {error in
                    if error == nil {
                        print("Successfully created folder")
                        self.uploadData(atIndices: indices, completion: completion)
                        // if folder could not be created, email data instead
                    } else {
                        print("Error creating folder: \(error!.localizedDescription)")
                        emailData ? (self.emailData(atIndices: indices, completion: completion)) : ()
                    }
                }
            } else {
                // if folder exists, upload the data
                print("Folder exists, uploading data")
                // set message to transfer started
                self.delegate?.transferController(self, didUpdateStateTo: .started, withMessage: NSLocalizedString("#transmissionProgress#", comment: ""))
                
                for i in indices {
                    
                    let dataObject = DataModel.init(withDict: (self.defaults.array(forKey: "storedData") as! [Dictionary<String, Any>])[i])
                    let filePath = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(dataObject.fileName))!
                    // try to load the data that is stored at the URL and send it
                    do {
                        let file = try Data(contentsOf: filePath)
                        var fileext = ".asc" //add .asc if encrypted
                        
                        // if the file was already encrypted during storage, just send it
                        var encryptedFile: Data?
                        if filePath.pathExtension.contains("asc") {
                            encryptedFile = file
                            fileext = ""
                        } else {
                            // otherwise, if encryption is enabled, it must succeed or this function returns
                            if self.defaults.bool(forKey: "isEncryptionEnabled") {
                                encryptedFile = EncryptionController.shared.encryptData(file)
                                guard (encryptedFile != nil) else {break}
                            } else {
                                // else, if encryption is disabled, the file is just passed through. This is NOT advised and should only be used for testing.
                                encryptedFile = file
                                fileext = ""
                            }
                        }
                        
                        self.webDav?.writeContents(path: folder + "/" + filePath.lastPathComponent + fileext, contents: encryptedFile, atomically: true, overwrite: true)
                        {error in
                            if error == nil {
                                print("Successfully uploaded file \(dataObject.fileName)")
                                // if transfer was successfull, check off the file in the database and increase progress by one
                                self.checkOffFile(i)
                            } else {
                                print("Error uploading file: \(error!.localizedDescription)")
                                // if the file fails to send, try to e-mail it instead, or if that is not wanted, show a failure message
                                emailData ? (self.emailData(atIndices: [i], completion: nil)) : (self.delegate?.transferController(self, didUpdateStateTo: .error, withMessage: error!.localizedDescription + NSLocalizedString("#transferFailed#", comment: "")))
                            }
                        }
                    } catch let error {
                        print("Error uploading file: \(error.localizedDescription)")
                        // if the file fails to send, try to e-mail it instead, or if that is not wanted, show a failure message
                        emailData ? (self.emailData(atIndices: [i], completion: nil)) : (self.delegate?.transferController(self, didUpdateStateTo: .error, withMessage: error.localizedDescription + NSLocalizedString("#transferFailed#", comment: "")))
                    }
                }
                
            }
        }
    }
    
    /// the variables used here are set in `Setup`
    func initEmail() {
        if defaults.bool(forKey: "emailData") {
            // set up email - these settings may differ for every use case. A secure connection is advisable.
            smtpSession = MCOSMTPSession()
            smtpSession.hostname = keychain.get("cred_emailhost")
            smtpSession.port = 25
            smtpSession.authType = MCOAuthType.saslPlain
            smtpSession.connectionType = MCOConnectionType.startTLS
            smtpSession.isCheckCertificateEnabled = true
        }
    }
    
    /// if desired, (encrypted) data can be sent as an email.
    func emailData(atIndices indices: [Int], completion: (()->())? = nil) {
        
        // if e-mail is disabled, return immediately and inform user that files could not be transferred
        if !defaults.bool(forKey: "emailData") {
            self.delegate?.transferController(self, didUpdateStateTo: .error, withMessage: NSLocalizedString("#transferInterrupted#", comment: ""))
               completion?()
        }
        
        if smtpSession == nil {
            initEmail()
        }
        
        let builder = MCOMessageBuilder()
        builder.header.to = [MCOAddress(displayName: "myndiOS", mailbox: keychain.get("cred_emailto")!)]
        builder.header.from = MCOAddress(displayName: "myndiOS", mailbox: keychain.get("cred_emailfrom")!)
        
        builder.header.subject = "[MYND] Files"
        builder.htmlBody = "New files attached </br>"
        
        // Retrieve all files that should be sent
        for i in indices {
            let attachment = MCOAttachment()
            
            let dataObject = DataModel.init(withDict: (defaults.array(forKey: "storedData") as! [Dictionary<String, Any>])[i])
            let filePath = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(dataObject.fileName))!
            
            // if encryption is enabled, you can only send encrypted files
            if defaults.bool(forKey: "isEncryptionEnabled") {
                attachment.mimeType = "application/pgp-encrypted"
            } else {
                            switch dataObject.type {
                            case .recording:
                                attachment.mimeType = "application/x-hdf5"
                            case .consent:
                                attachment.mimeType =  "application/pdf"
                            case .questionnaire:
                                attachment.mimeType = "application/json"
                            }
            }
            
            do {
                let data = try Data(contentsOf: filePath)
                // if the file is already encrypted, or encryption is disabled, just attach it to the email
                if filePath.pathExtension.contains("asc")  || !defaults.bool(forKey: "isEncryptionEnabled") {
                    attachment.filename = (dataObject.fileName)
                    attachment.data = data
                } else {
                // else, encrypt the data here
                    attachment.filename = (dataObject.fileName + ".asc")
                    attachment.data = EncryptionController.shared.encryptData(data)
                }
                builder.addAttachment(attachment)
            } catch {
                print("Cloud not load data at \(dataObject.fileName)")
            }
        }
        
        // Send e-mail
        let sendOperation = smtpSession.sendOperation(with: builder.data()!)
        
// Alternative: Encrypt the whole e-mail and not just the attachements if desired
//        guard let encryptedData = EncryptionController.shared.encryptData(builder.dataForEncryption()) else {completion?(); return}
//        let rfc822Data = builder.openPGPEncryptedMessageData(withEncryptedData: encryptedData)
//        let sendOperation = smtpSession.sendOperation(with: rfc822Data!)
        
        
        sendOperation?.start { (error) -> Void in
            if error != nil {
                self.delegate?.transferController(self, didUpdateStateTo: .error, withMessage: (error?.localizedDescription)! + NSLocalizedString("#transferInterrupted#", comment: ""))
                completion?()
            } else {
                // Set transmission to true
                for i in indices {
                    self.checkOffFile(i)
                }
                completion?()
            }
        }
    }
    
    /// The `DataModel` for each file contains a `transmission` flag that is set to true if transmission was successful.
    func checkOffFile(_ index: Int) {
        var storedData = defaults.array(forKey: "storedData") as! [Dictionary<String, Any>]
        storedData[index]["transmitted"] = true
        defaults.set(storedData, forKey: "storedData")
        progress += 1
        print("progress for uploading: \(progress) out of \(max)")
        delegate?.transferController(self, didUpdateProgressTo: progress/max)
        if progress >= max {
            delegate?.transferController(self, didUpdateStateTo: .completed, withMessage: NSLocalizedString("#transferSuccessful#", comment: ""))
        }
    }
    
    /// this function can be called whereever to upload pending items
    func uploadPending(completion: (()->())? = nil){
        guard  defaults.bool(forKey: "isTransferEnabled") else {
            completion?()
            return
        }
        
        // Get all unsent data indices
        var unsentDataIndices = [Int]()
        let storedData = self.defaults.array(forKey: "storedData") as! [Dictionary<String, Any>]
        for (n,c) in storedData.enumerated() {
            if !(c["transmitted"] as! Bool) {
                unsentDataIndices.append(n)
            }
        }
        if !unsentDataIndices.isEmpty {
            transferData(atIndices: unsentDataIndices)
        }
    }
    
    enum ReachabilityStatus {
        case notReachable
        case reachableViaWWAN
        case reachableViaWiFi
    }
    
    /// via https://stackoverflow.com/questions/37919315/how-can-i-check-mobile-data-or-wifi-is-on-or-off-ios-swift
    var currentReachabilityStatus: ReachabilityStatus {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return .notReachable
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return .notReachable
        }
        
        if flags.contains(.reachable) == false {
            // The target host is not reachable.
            return .notReachable
        }
        else if flags.contains(.isWWAN) == true {
            // WWAN connections are OK if the calling application is using the CFNetwork APIs.
            return .notReachable
        }
        else if flags.contains(.connectionRequired) == false {
            // If the target host is reachable and no connection is required then we'll assume that you're on Wi-Fi...
            return .reachableViaWiFi
        }
        else if (flags.contains(.connectionOnDemand) == true || flags.contains(.connectionOnTraffic) == true) && flags.contains(.interventionRequired) == false {
            // The connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs and no [user] intervention is needed
            return .reachableViaWiFi
        }
        else {
            return .notReachable
        }
    }
    

    /// A global announcement can be placed as a JSON file in the root directory of an optional download webdav. If the JSON in this location is newer than the lastly downloaded message, it is downloaded by `TransferController` and displayed in `HomeViewController` when the subject starts the next scenario. An announcement can also be located in a folder that is named like the UUID of a user. This can be helpful if the announcement only affects a subset of participants. NEVER post personal information in these locations.
     func checkForMessage(inUUIDFolder: Bool = false) {
         
         let folder = defaults.string(forKey: "uuid")!
         downloadWebDav == nil ? (initWebDav()) : ()
         
         // silently do nothing if wifi is disconnected
         guard currentReachabilityStatus == .reachableViaWiFi else {
             return
         }
         
         // check on top directory, or in personal folder if desired
         var path = "message.json"
         if inUUIDFolder {
             path = folder + "/" + path
         }
         
         // look up message in folder, check modified date
         downloadWebDav.attributesOfItem(path: path) {
             [weak self] file, error in
             if let file = file {
                 // check whether date of file is newer than the last one presented
                 guard let lastDate = self?.defaults.object(forKey: "dateOfLastMessage") as? Date else {
                     self?.downloadAndSetMessage(file: file, atPath: path)
                     return
                 }
                 
                 // if this is the newest file, download it
                 if file.modifiedDate! > lastDate {
                     self?.downloadAndSetMessage(file: file, atPath: path)
                 } else {
                     // if this isnt the newest file and we were on root level, check in the UUID folder afterwards
                     inUUIDFolder ? () : (self?.checkForMessage(inUUIDFolder: true))
                 }
             }
             
             if let error = error {
                 print(error.localizedDescription)
             }
         }
     }
     
    /// the message itself is handled by `BannerController`
     private func downloadAndSetMessage(file: FileObject, atPath path: String) {
         
         // download the message and prepare a notification
         downloadWebDav.contents(path: path) { [weak self]
             data,error in
             if let data = data {
                 do {
                     // set timeStamp of the newest message
                     self?.defaults.set(file.modifiedDate!, forKey: "dateOfLastMessage")
                     let json = try JSON(data: data)
                     BannerController.shared.setRemoteMessage(messageJSON: json)
                 } catch let error {
                     print(error.localizedDescription)
                 }
             }
             if let error = error {
                 print(error.localizedDescription)
             }
         }
     }
}
