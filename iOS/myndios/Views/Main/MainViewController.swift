//
//  MainViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 24.11.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit

/// A view that controls the general functionality of the application
class MainViewController: UIViewController {
    
    weak var nav: UINavigationController!
    
    /////////////////////////
    // MARK: - View Control
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make sure there is an active study, otherwise send to signup, but do not erase any data
        guard StudyController.shared.currentStudy != nil else {
            print("There is no current study!")
            returnToLogin(eraseData: false)
            return
        }

        nav = (children.first! as! UINavigationController)
        nav.pushViewController(HomeViewController.make(self), animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.modalPresentationStyle = .fullScreen
        self.navigationController?.modalPresentationStyle = .fullScreen
        TTSController.shared.stop()
    }
    
    /////////////////////////
    // MARK: - Presentation
         
    /**
     Returns to the initial login screen, optionally erases all data
     */
    func returnToLogin(eraseData: Bool = false) {
        if eraseData {
            _ = StorageController.shared.eraseData()
            Constants.setUserDefaults()
        }
        
        let vc = storyboard?.instantiateViewController(withIdentifier: "LoginView")
        vc?.modalPresentationStyle = .fullScreen
        present(vc!, animated: true, completion: nil)
    }
}
