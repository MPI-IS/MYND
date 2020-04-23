//
//  EncyptionController.swift
//  myndios
//
//  Created by Matthias Hohmann on 27.04.20.
//  Copyright © 2020 Matthias Hohmann. All rights reserved.
//
//  Note: The functionality of this class was previously part of other Controllers, but has now been centralized in this object in order to make it easier to enable or disable it due to required licensing of OpenPGP.

import Foundation

#if canImport(ObjectivePGP)
// make sure that you obtain the appropriate license for your use-case. If this library is missing, this command is skipped.
import ObjectivePGP
#endif

class EncryptionController: NSObject {
    
    static let shared = EncryptionController()
    private let defaults = UserDefaults.standard
    
    func encryptData(_ data: Data, armored: Bool = true) -> Data? {
        
        // if encryption of data is globally disabled, return immediately with nil
        if !defaults.bool(forKey: "isEncryptionEnabled") {
            return nil
        }
        
        // if the library is available and encryption is enabled, try to encrypt the data. Else, immeditaly return with an error.
        #if canImport(ObjectivePGP)
        
        // ensure that a key is in place, otherwise crash
        guard let keyURL = Bundle.main.url(forResource: "key", withExtension: ".asc"),
            let keyData = try? Data(contentsOf: keyURL),
            let key = try? ObjectivePGP.readKeys(from: keyData) else { fatalError(" Can't find key file")}
        
        var encrypted: Data?
        do {
            if armored {
                // ASCII armor is enabled by default. To learn more about this, see, e.g., https://www.techopedia.com/definition/23150/ascii-armor
                encrypted = Armor.armored(try ObjectivePGP.encrypt(data, addSignature: false, using: key), as: .message).data(using: .utf8)
            } else {
                encrypted = try ObjectivePGP.encrypt(data, addSignature: false, using: key)
            }
        } catch let error{
            fatalError(error.localizedDescription)
        }
        
        return encrypted
        #else
        fatalError("ERROR: Can't find library, but encryption was enabled.")
        #endif
    }
}
