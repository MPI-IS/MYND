//
//  PauseViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 29.11.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import BatteryView
import M13Checkbox

/**
 `PauseView` informs subjects about their progress, once they successfully completed one block of trials in a scenario. They can choose to continue with the next block of trials, in which case they will be forwarded to `FittingView` in `checkUp` mode.  If they finished all blocks in a scenario and decide to continue with the next scenario, `shortFitting` mode will be enabled, preparation will be skipped, and the EEG recording process begins again with `DetailView`. If they finished all scenarios for the day, they will be returned to the `HomeView`, and a `WaitView` will lock the screen until the time out has passed.
 */
class PauseViewController: UIViewController{
    
    @IBOutlet weak var pauseText: UILabel!
    @IBOutlet weak var pauseTitle: UILabel!
    @IBOutlet weak var scenarioBubble: ScenarioBubble!
    @IBOutlet weak var continueButton: UIButton!
    
    weak var sessionVC: SessionViewController! = nil
    
    static func make(_ sessionVC: SessionViewController) -> PauseViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Pause") as! PauseViewController
        viewController.sessionVC = sessionVC
        return viewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        switch sessionVC.sessionResult {
        case .none:
            break
        case .didFinishBlock:
            pauseTitle.text = NSLocalizedString("#blockCompletedTitle#", comment: "")
            pauseText.text = NSLocalizedString("#blockCompletedText#", comment: "")
            continueButton.setTitle(NSLocalizedString("#continueBlock#", comment: ""), for: .normal)
        case .didFinishScenario:
            pauseTitle.text = NSLocalizedString("#scenarioCompletedTitle#", comment: "")
            pauseText.text = NSLocalizedString("#scenarioCompletedText#", comment: "")
            continueButton.setTitle(NSLocalizedString("#continueScenario#", comment: ""), for: .normal)
            // preload the next scenario just in case
            
        case .didFinishDay:
            pauseTitle.text = NSLocalizedString("#dayCompletedTitle#", comment: "")
            pauseText.text = NSLocalizedString("#dayCompletedText#", comment: "")
            continueButton.setTitle(NSLocalizedString("#endScenario#", comment: ""), for: .normal)
        }
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let eegBatteryView = BatteryView()
        eegBatteryView.level = Int(sessionVC.dataController.battery!)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: eegBatteryView)
        TTSController.shared.say(pauseText.text!)
        
        scenarioBubble.setScenario(sessionVC.session)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scenarioBubble.checkbox.setCheckState(.unchecked, animated: true)
        TTSController.shared.stop()
        navigationItem.rightBarButtonItem = nil
    }
    
    @IBAction func continueExperiment() {
        
        // If we finished the whole study end this session
        switch sessionVC.sessionResult {
        case .none, .didFinishBlock:
            sessionVC.goTo(phase: .checkUp)
        case .didFinishScenario:
            sessionVC.setSession(StudyController.shared.currentStudy!.getSession(), shortFitting: true)
            sessionVC.goTo(phase: .detail)
        case .didFinishDay:
           sessionVC.endSession()
        }
    }
    
    @IBAction func cancelExperiment() {
        sessionVC.endSession()
    }
}
