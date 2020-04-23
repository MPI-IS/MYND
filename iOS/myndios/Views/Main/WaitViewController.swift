//
//  WaitViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 14.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import M13Checkbox

enum WaitReason: String {
    case didFinishDay, didFinishStudy
}

/// See `HomeView` for more details. The `WaitView` is called immediately by home view if all scenarios were completed and the time out date has not passed yet. It displays various wait messages based on the current state and locks the screen until the subject is allowed to continue. In developer-mode, this waiting time can be skipped, and pressing the continue button on the final study completion message will reset progress.
class WaitViewController: UIViewController {
    
    let defaults = UserDefaults.standard
    
    @IBOutlet weak var pauseText: UILabel!
    @IBOutlet weak var pauseTitle: UILabel!
    @IBOutlet weak var checkBox: M13Checkbox!
    @IBOutlet weak var continueButton: UIButton!
    
    var dayTimeOutChecker: Timer?
    var timeLeft: TimeInterval?
    var reason: WaitReason = .didFinishDay
    weak var dayTimeOutListener: DayTimeOutListener?
    
    static func make(reason: WaitReason) -> WaitViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WaitView") as! WaitViewController
        viewController.reason = reason
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkBox.backgroundColor = UIColor.clear
        checkBox.stateChangeAnimation = .bounce(.fill)
        checkBox.tintColor = UIColor.MP_Blue
        checkBox.boxLineWidth = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkBox.setCheckState(.checked, animated: true)
        setButtonStateActive(false)
        switch reason {
        case .didFinishDay:
            updateMessage()
            dayTimeOutChecker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateMessage()
            }
        case .didFinishStudy:
            if defaults.bool(forKey: "isDeveloperModeEnabled") {
                setButtonStateActive(false)
            } else {
                continueButton.isHidden = true
            }
            checkBox.tintColor = .MP_Green
            pauseTitle.text = NSLocalizedString("#studyCompleteTitle#", comment: "")
            pauseText.text = NSLocalizedString("#studyCompleteMessage#", comment: "")
            TTSController.shared.say(pauseText.text!)
        }
    }
    
    func updateMessage() {
        // get base message
        let completedMinutes = Int(((StudyController.shared.currentStudy!.getDuration().dayTotal - StudyController.shared.currentStudy!.getDuration().dayRemaining) / 60).rounded())
        let message = String(format: NSLocalizedString("#waitMessage#", comment: ""), completedMinutes)
        
        // get state of timeOut
        var placeholders = [String: String]()
        placeholders["#timeOutMessage#"] = updateTimeOutWithMessage()
        
        // not implemented: the pause message can display global statistics that could be downloaded from somewhere during the course of the study. Here, all placeholders for these potential numbers are just removed.
        
        // the pause message is updated in regular intervals, if it differs from the previous message in any way, it is read out again.
        placeholders["#globalStatsMessage#"] = ""
        let m = message.withFilledPlaceholders(withOptionalArguments: placeholders)
        if m != pauseText.text {
            pauseText.text = m
            TTSController.shared.say(m)
        }
    }
    
    private func updateTimeOutWithMessage() -> String {
        let timeOut = StudyController.shared.currentStudy!.checkForDayTimeOut()
        switch timeOut.state {
        case .none:
            self.setButtonStateActive(true)
            self.dayTimeOutChecker?.invalidate()
            return NSLocalizedString("#continueMessage#", comment: "")
        case .timeOut:
            self.setButtonStateActive(true)
            self.dayTimeOutListener?.study(StudyController.shared.currentStudy!, didChangeTimeOutStateTo: .timeOut)
            self.dayTimeOutChecker?.invalidate()
            return NSLocalizedString("#continueMessage#", comment: "")
        case .wait:
            self.setButtonStateActive(false)
            self.timeLeft = timeOut.timeInterval
             return NSLocalizedString("#timeOutMessage#", comment: "").replacingOccurrences(of: "%s", with: timeOut.timeInterval.stringFromTimeInterval())
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dayTimeOutChecker?.invalidate()
    }
    
    func setButtonStateActive(_ active: Bool) {
        if active {
            UIView.animate(withDuration: 0.5) {
                self.continueButton.layer.backgroundColor = UIColor.MP_Blue.cgColor
            }
            continueButton.isEnabled = true
        } else {
            UIView.animate(withDuration: 0.5) {
                self.continueButton.layer.backgroundColor = UIColor.MP_Grey.cgColor
            }
            defaults.bool(forKey: "isDeveloperModeEnabled") ? (): (self.continueButton.isEnabled = false)
        }
    }
    
    @IBAction func continueExperiment() {
        if defaults.bool(forKey: "isDeveloperModeEnabled") {
            // if the study was finished, reset everything. only available in dev-mode
            if reason == .didFinishStudy {
                StudyController.shared.currentStudy!.resetStudy()
                StudyController.shared.saveCurrentStudyProgress()
            // if there is still a time Out period happening, force it to time out
            } else {
                dayTimeOutListener?.study(StudyController.shared.currentStudy!, didChangeTimeOutStateTo: .timeOut)
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
}
