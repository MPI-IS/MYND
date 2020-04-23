//
//  MNDSessionVCBase.swift
//  myndios
//
//  Created by Matthias Hohmann on 21.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit

/// States with which a session can end
enum MNDSessionEndReason: String {
    case error, cancel, complete
}

/// Results that can be acheived in a session
enum MNDSessionResult: String {
    case none, didFinishBlock, didFinishScenario, didFinishDay
}

/// Steps that can be shown by the StepPageViewController
enum MNDSessionStep: String {
    case detail, boarding, noise, fitting, scenario, survey, pause, checkUp, upload, introCompleted, timeOutStarted, finish, error, cancel, rawData
}

/**
 Base Class for any view that will handle a session, can be either a survey or a EEG recording
*/
class MNDSessionVCBase: UIViewController {
    
    // Globals
    let defaults = UserDefaults.standard
    let nc = NotificationCenter.default
    
    // Session Information
    var session: ScenarioModel! = nil
    var sessionStartTime: Date! = nil
    var sessionResult: MNDSessionResult = .none
    var isExperimentRunning: Bool = false
    
    // View
    var flowVC = MNDSessionFlowViewController()
    var currentPhase: MNDSessionStep!
    
    /// Add stepVC as subView so it will be displayed
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(flowVC)
        view.addSubview(flowVC.view)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionStartTime = Date()
        navigationController?.navigationBar.tintColor = Constants.appTint
    }
    
    // Set the SessionViewController to display a specific session
    func setSession(session: ScenarioModel?) {
        guard let session = session else {return}
        
        self.session = session
    }
    
    func goTo(phase: MNDSessionStep) {
        currentPhase = phase
        flowVC.goTo(phase: phase)
    }
}
