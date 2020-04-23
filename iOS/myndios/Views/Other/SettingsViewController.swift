//
//  SettingsViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 21.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import KeychainSwift

/// Settings are described more extensively in `Setup`. Additionally, the `SettingsView` includes functions to reset the application, it contains credits, and links to the `DataTableView` where past recordings can be seen, deleted, and shared (in dev-mode).
class SettingsViewController: UITableViewController {
    
    let defaults:UserDefaults = UserDefaults.standard
    let keychain = KeychainSwift()
    
    // Delegates
    weak var mainVC: MainViewController! = nil
    
    @IBOutlet weak var developerSwitch: UISwitch!
    
    @IBOutlet weak var museSwitch: UISwitch!
    @IBOutlet weak var auxElectrodeSwitch: UISwitch!
    
    @IBOutlet weak var transferSwitch: UISwitch!
    
    @IBOutlet weak var uuidLabel: UILabel!
    @IBOutlet weak var ttsSwitch: UISwitch!
    @IBOutlet weak var shortInstructionsSwitch: UISwitch!
    
    @IBOutlet weak var timeOutSpinner: UIDatePicker!
    @IBOutlet weak var eraseButton: UIButton!
    
    
    ////
    // Factory
    ////
    
    static func make(_ mainVC: MainViewController) -> SettingsViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Settings") as! SettingsViewController
        viewController.mainVC = mainVC
        return viewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainVC.nav.navigationBar.backgroundColor = UIColor.clear
        mainVC.nav.navigationBar.setBackgroundImage(nil, for: .default)
        updateSettingsView()
    }
    
    /// this will check against the password set in `Setup`
    @IBAction func toggleDeveloperMode(_ sender: UISwitch) {
        if !defaults.bool(forKey: "isDeveloperModeEnabled") {
            let alert = UIAlertController(title: "", message: "Please enter the developer password to continue.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                self.defaults.set(false, forKey: "isDeveloperModeEnabled")
                self.updateSettingsView()
            })
            alert.addAction(UIAlertAction(title: "Enable", style: .default) { action in
                let firstTextField = alert.textFields![0] as UITextField
                if firstTextField.text! == self.keychain.get("cred_developerMode")! {
                    self.defaults.set(true, forKey: "isDeveloperModeEnabled")
                    print(self.defaults.bool(forKey: "isDeveloperModeEnabled"))
                } else {
                    self.defaults.set(false, forKey: "isDeveloperModeEnabled")
                }
                self.updateSettingsView()
            })
            alert.addTextField { (textField : UITextField!) -> Void in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            }
            self.present(alert, animated: true, completion: nil)
        } else {
            self.defaults.set(false, forKey: "isDeveloperModeEnabled")
            updateSettingsView()
        }
    }
    
    @IBAction func toogleSource(_ sender: UISwitch) {
        
        if sender.isOn {
            defaults.set("Muse", forKey: "device")
        } else {
            defaults.set("Oscillator", forKey: "device")
        }
        updateSettingsView()
    }
    
    @IBAction func toggleAux(_ sender: UISwitch) {
        defaults.set(sender.isOn, forKey: "isAuxEnabled")
    }
    
    @IBAction func showCredits(_ sender: Any) {
        let vc = CreditsViewController.make()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func toogleTransfer(_ sender: UISwitch) {
        defaults.set(sender.isOn, forKey: "isTransferEnabled")
        updateSettingsView()
    }
    
    @IBAction func toogleTTS(_ sender: UISwitch) {
        defaults.set(sender.isOn, forKey: "isTTSEnabled")
        updateSettingsView()
    }
    
    @IBAction func chanageNames(_ sender: UIButton) {
        present(CustomAlertController.names(), animated: true, completion: nil)
    }
    
    @IBAction func showRecordedData(_ sender: Any) {
        let vc = DataTableViewController.make(mainVC)
        mainVC.nav.pushViewController(vc, animated: true)
    }
    
    @IBAction func recoverLastMessag(_ sender: Any) {
        if defaults.object(forKey: "dateOfLastMessage") != nil {
            defaults.set(true, forKey: "shouldPresentRemoteMessage")
        }
    }
    
    @IBAction func eraseData(_ sender: UIButton) {
        let alert = UIAlertController(title: "Erase Data", message: "You are about to reset this app to its defaults. All recordings and personal settings will be deleted.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Erase", style: .destructive, handler:
            { [weak self] _ in
                self?.mainVC.returnToLogin(eraseData: true)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func shortInstructionsEnabled(_ sender: UISwitch) {
        defaults.set(sender.isOn, forKey: "isShortInstructionEnabled")
    }
    
    fileprivate func updateSettingsView() {
        developerSwitch.setOn(defaults.bool(forKey: "isDeveloperModeEnabled"), animated: true)
        
        museSwitch.isEnabled = defaults.bool(forKey: "isDeveloperModeEnabled")
        switch defaults.string(forKey: "device")! {
        case "Muse":
           museSwitch.setOn(true, animated: true)
        default:
            museSwitch.setOn(false, animated: true)
        }
        
        auxElectrodeSwitch.setOn(defaults.bool(forKey: "isAuxEnabled"), animated: true)
        auxElectrodeSwitch.isEnabled = defaults.bool(forKey: "isDeveloperModeEnabled")
        
        transferSwitch.setOn(defaults.bool(forKey: "isTransferEnabled"), animated: true)
        transferSwitch.isEnabled = defaults.bool(forKey: "isDeveloperModeEnabled")
        
        ttsSwitch.setOn(defaults.bool(forKey: "isTTSEnabled"), animated: true)
        shortInstructionsSwitch.setOn(defaults.bool(forKey: "isShortInstructionEnabled"), animated: true)
        
        uuidLabel.text = (defaults.object(forKey: "uuid") as! String)
        
        timeOutSpinner.isEnabled = defaults.bool(forKey: "isDeveloperModeEnabled")
        timeOutSpinner.countDownDuration = TimeInterval(defaults.integer(forKey: "timeOutTimeInterval"))
        eraseButton.isEnabled = defaults.bool(forKey: "isDeveloperModeEnabled")
    }
    
    @IBAction func setTimeOut(_ sender: UIDatePicker) {
        defaults.set(sender.countDownDuration, forKey: "timeOutTimeInterval")
    }
    
}

enum CustomAlertController {
    /// Alert controller for entering patient and caregiver names
    static func names() -> UIAlertController {
        let defaults = UserDefaults.standard
        // instantiate view controller
        let alert = UIAlertController(title: NSLocalizedString("#enterNamesTitle#", comment: ""), message: NSLocalizedString("#enterNamesText#", comment: ""), preferredStyle: .alert)
        // add cancel and OK buttons
        alert.addAction(UIAlertAction(title: NSLocalizedString("#cancel#", comment: ""), style: .cancel) { _ in
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("#ok#", comment: ""), style: .default) { action in
            
            // override names if any
            if let patientName = (alert.textFields![0] as UITextField).text,
                !patientName.isEmpty {
                defaults.set(patientName, forKey: "patientName")
            }
            
            // If subject has a helper, put the name in
            if let helperName = (alert.textFields![1] as UITextField).text,
                !helperName.isEmpty {
                defaults.set(true, forKey: "hasHelper")
                defaults.set(helperName, forKey: "helperName")
            } else {
                // If no helper was specified, make the name of patient and helper the same
                defaults.set(false, forKey: "hasHelper")
                defaults.set(defaults.string(forKey: "patientName"), forKey: "helperName")
            }
            
        })
        
        alert.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = NSLocalizedString("#patientName#", comment: "")
            textField.isSecureTextEntry = false
        }
        alert.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = NSLocalizedString("#helperName#", comment: "")
            textField.isSecureTextEntry = false
        }
        return alert
    }
}
