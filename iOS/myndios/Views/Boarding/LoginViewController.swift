//
//  LoginViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 15.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit

/// The `LoginView` is essentially the sign-up view of the application. It sets a current study, initiates boarding if the subject presses the button, and transitions to the `MainView` once boarding was completed. In developer-mode, the view can be tapped anywhere to skip sign-up (a UUID will be generated anyways).
class LoginViewController: UIViewController, BoardingListener {
    
    let defaults: UserDefaults = UserDefaults.standard
    let nc = NotificationCenter.default
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var backgroundView: MNDVisualInstructionView!

    var boardingVC: BoardingViewController! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set visuals
        backgroundView.set(visualInstructionString: "intro.mov")
        
        // Set study.
        StudyController.shared.loadAndSetStudy(.mynd_example)
    }
    
    @IBAction func getStarted(sender : Any) {
            if ((StudyController.shared.currentStudy?.consent.document) != nil) {
                boardingVC = BoardingViewController()
                boardingVC.listener = self
                present(boardingVC, animated: true, completion: nil)
            } else {
                nc.postBanner(message: "Could not find Consent.")
            }
        
    }
    
    @IBAction func skipSignup(_ sender: Any) {
        if defaults.bool(forKey: "isDeveloperModeEnabled") {
            boardingVC = BoardingViewController()
            boardingVC.listener = self
            boardingVC.enroll()
            performSegue(withIdentifier: "mainViewSegue", sender: self)
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func boardingCompleted(_ boardingViewController: BoardingViewController, success: Bool = false) {
        boardingViewController.dismiss(animated: true, completion: success ? {self.performSegue(withIdentifier: "mainViewSegue", sender: self)} : nil)
    }
}
