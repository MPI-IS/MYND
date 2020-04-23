//
//  Setup.swift
//  myndios
//
//  Created by Matthias Hohmann on 22.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import AVFoundation
import KeychainSwift

/**
 This struct contains variables that are stored in permanent user defaults by `AppDelegate` when the app is first started. There are two types of variables:
 - *Initial variables*: These are variables that users may change during use, e.g., their name.
 - *Permanent variables*: These are important experimenter settings, e.g., encryption and transfer, as well as important credentials, like the WebDav upload user and password for the current study. They can only be changed here, and not through the user interface. The app needs to be recompiled and restarted if these settings are changed.
 */
struct Constants {
    
    /// The tint of the application is the default color for all elements
    static let appTint: UIColor = UIColor.MP_Blue
    
    /// Set UserDefaults based on which environment the app is running in
    static func setUserDefaults() {
        let defaults: UserDefaults = UserDefaults.standard
        
        // make sure all previous defaults are erased
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // INITIAL VARIABLES: THESE CAN BE CHANGED IN THE UI
        
        // Device
        // supported: Muse and Oscillator
        defaults.set("Muse", forKey: "device")
        // supported: true, false. Changes channel count from 4 to 5
        defaults.set(false, forKey: "isAuxEnabled")
        
        // Data Storage
        // Should data be transferred automatically or just stored on device? True, false
        defaults.set(true, forKey: "isTransferEnabled")
        defaults.set([Dictionary<String, Any>](), forKey: "storedData")
        
        // User
        // the UUID is automatically generated and stored
        let uuid = UUID().uuidString
        defaults.set(uuid, forKey: "uuid")
        // Text-to-speech can be disabled, however a voice WILL always read out banner notifications and prompts during the recording, to ensure that eyes-closed experiments can be conducted.
        defaults.set(true, forKey: "isTTSEnabled")
        
        // should shortened instructions play during preparation
        defaults.set(false, forKey: "isShortInstructionEnabled")
        
        defaults.set("Participant", forKey: "patientName")
        defaults.set("Helper", forKey: "helperName")
        // if, e.g., a relative helps with the setup, they will be addressed with their own name in the appropriate moment. If this is set to false during boarding, helperName will be equal to patientName.
        defaults.set(false, forKey: "hasHelper")
        
        // whether an iOS notification informs subjects that the next set of scenarios can be recorded. This permission needs to be granted once during boarding by the user as well.
        defaults.set(true, forKey: "areNotificationsEnabled")
        
        // Developer mode can be enabled through a password-protected switch in the UI. It allows to change a few technical settings and skip fitting prequisites, however it does NOT allow alteration of the permanent variables below, including encryption.
        defaults.set(true, forKey: "isDeveloperModeEnabled")
        
        // run index, increases automatically. This is reset to zero in developer-mode, if you long press on a scenario to reset its progress.
        defaults.set(0, forKey: "currentRunIndex")
        // this is set in seconds. "time out internval" refers to the time subjects have to complete a day of recordings after starting the first one.
        defaults.set(12*60*60, forKey: "timeOutTimeInterval")
        
        // Messaging system, can be used for global announcements and technical support
        defaults.set("", forKey: "remoteMessageTitle")
        defaults.set("", forKey: "remoteMessageText")
        defaults.set(false, forKey: "shouldPresentRemoteMessage")
        defaults.set(nil, forKey: "dateOfLastMessage")
        
        // PERMANENT VARIABLES: THESE CANNOT BE CHANGED ELSEWHERE, APP NEEDS TO BE RECOMPILED AFTERWARDS
        
        // should data be encrypted in general. This requires a licensed OpenPGP library. If OpenPGP is not available and this is set to true, the app will crash. Make sure to add the public `key.asc` PGP key to this code. It is advisable to change this key for every study. Do NOT use the key that came with this repository.
        defaults.set(true, forKey: "isEncryptionEnabled")
        
        // if this is set to true, recorded data is immediately encrypted during storage with the public key. In this case, the participant immediately loses all access to their data after recording, and data cannot be used for post-hoc processing and feedback on device.
        defaults.set(true, forKey: "encryptDuringStorage")
        
        // if you do not have a server, or if the connection cannot be established, you can choose to send data via e-mail as back-up.
        // it is advisable to use this option only with encryption enabled. The e-mail itself will be unencrypted, and the encrypted files will be attached (the alternative to encrypt the whole e-mail is commented out in `TransferController`). This option is set up to work with an SMTP server that does not require credentials for sending e-mails between internal addresses.
        defaults.set(true, forKey: "emailData")
        
        // credentials for transfer, stored in the iOS keychain for this app only (encrypted)
        let keychain = KeychainSwift()
        keychain.clear()
        
        // host server for sending encrypted e-mails.
        keychain.set("mailhost.youinstitution.com", forKey: "cred_emailhost")
        keychain.set("first.last@yourinstitution.com", forKey: "cred_emailto")
        keychain.set("first.last@yourinstitution.com", forKey: "cred_emailfrom")
        
        // webdav location and credentials for file upload. You should change them for every study. Make sure the user only has upload rights and only exists for this study. A https webdav connection adds an extra layer of encryption.
        keychain.set("https://webdav.yourinstitution.com/upload/", forKey: "cred_webdavupload")
        keychain.set("mynd-upload", forKey: "cred_userupload")
        keychain.set("doun-jous-zool", forKey: "cred_passwordupload")
        
        // webdav location and credentials for downloading annoucements and technical support messages. You should change them for every study. Make sure the user only has download rights and only exists for this study. NEVER post personal information in these messages. A https webdav connection adds an extra layer of encryption.
        keychain.set("https://webdav.yourinstitution.com/download/", forKey: "cred_webdavdownload")
        keychain.set("mynd-download", forKey: "cred_userdownload")
        keychain.set("nant-deet-zoog", forKey: "cred_passworddownload")
        
        // password to enable developer mode
        keychain.set("twah-kiwn-pec", forKey: "cred_developerMode")
    }
}
