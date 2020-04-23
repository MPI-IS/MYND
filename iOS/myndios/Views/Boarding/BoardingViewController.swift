//
//  BoardingViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 08.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import ResearchKit
import UserNotifications

protocol BoardingListener: class {
    func boardingCompleted(_ boardingViewController: BoardingViewController, success: Bool)
}

/// The `BoardingView` embeds the *ResearchKit* `ORKTaskViewController` that manages the consent steps and other options. It also passes any setup choices and prepares the consent for storage as PDF. 
class BoardingViewController: UIViewController {
    
    weak var listener: BoardingListener?
    let defaults = UserDefaults.standard
    let nc = NotificationCenter.default
    
    override func viewDidLoad() {
        if let steps = StudyController.shared.currentStudy?.consent.steps {
            let task = ORKNavigableOrderedTask(identifier: "Consent", steps: steps)
            
            let vc = ORKTaskViewController(task: task, taskRun: nil)
            vc.view.tintColor = Constants.appTint
            vc.delegate = self
            addChild(vc)
            self.view.addSubview(vc.view)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.subviews.forEach {
            $0.scaleToFillSuperView(withConstant: 0.0)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TTSController.shared.stop()
    }
    
    func enroll() {
        StudyController.shared.currentStudy?.enrolled = true
        StudyController.shared.currentStudy?.active = true
        StudyController.shared.saveCurrentStudyProgress()
        self.listener?.boardingCompleted(self, success: true)
    }
    
}

extension BoardingViewController: ORKTaskViewControllerDelegate {
    func taskViewControllerSupportsSaveAndRestore(_ taskViewController: ORKTaskViewController) -> Bool {
        return false
    }
    
    /// if the user decides to not consent, dismiss the boarding procedure and reset
    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {
        if let stepResult = result.stepResult(forStepIdentifier: "ConsentReviewStep"),
            let signatureResult = stepResult.results?.first as? ORKConsentSignatureResult,
            !signatureResult.consented {
            listener?.boardingCompleted(self, success: false)
            TTSController.shared.stop()
        }
    }
    
    /// handle any processing before a certain step will appear
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        
        if let step = stepViewController.step as? ORKQuestionStep {
            TTSController.shared.say(step.text!)
        } else if let step = stepViewController.step as? ORKInstructionStep {
            TTSController.shared.say(step.text!)
        } else if let step = stepViewController.step as? ORKConsentReviewStep {
            TTSController.shared.say(step.reasonForConsent!)
        }
    }
    
    /// handle any processing after a certain step did dissapear
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillDisappear stepViewController: ORKStepViewController, navigationDirection direction: ORKStepViewControllerNavigationDirection) {
        TTSController.shared.stop()
        switch stepViewController.step!.identifier {
        case "tts":
            guard let choice = (taskViewController.result.stepResult(forStepIdentifier: "tts")?.results?.first as? ORKChoiceQuestionResult)?.choiceAnswers?.first as? NSNumber else {break}
            choice == 1 ? (defaults.set(true, forKey: "isTTSEnabled")) : (defaults.set(false, forKey: "isTTSEnabled"))
        case "notifications":
            // Ask permission to send notifications
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
                [weak self] (permissionGranted, error) in
                self?.defaults.set(permissionGranted, forKey: "areNotificationsEnabled")
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        case "wifi":
            if TransferController.shared.currentReachabilityStatus != .reachableViaWiFi {
                let alert = UIAlertController(title: NSLocalizedString("#noWiFiTitle#", comment: ""), message: NSLocalizedString("#noWiFiText#", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        default:
            break
        }
    }
    
    /// store the consent results
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        
        guard reason == .completed else {
            nc.postBanner(message: "Consent process canceled")
            listener?.boardingCompleted(self, success: false)
            return
        }
        
        let result = taskViewController.result
        
        // Consent
        if let stepResult = result.stepResult(forStepIdentifier: "ConsentReviewStep"),
            let signatureResult = stepResult.results?.first as? ORKConsentSignatureResult {
            // Only proceed if consented
            guard signatureResult.consented else {listener?.boardingCompleted(self, success: false); return}
            StorageController.shared.storeConsent(of: StudyController.shared.currentStudy!, withResult: result) {self.enroll(); TransferController.shared.uploadPending()}
        }
        
        // Patient Name
        if let patientName = result.stepResult(forStepIdentifier: "patientName")?.results?.first! as? ORKTextQuestionResult {
            if patientName.textAnswer != nil {
                defaults.set(patientName.textAnswer?.alphanumeric, forKey: "patientName")
            }
        }
        
        // Caregiver Name
        if let caregiverName = result.stepResult(forStepIdentifier: "caregiverName")?.results?.first! as? ORKTextQuestionResult {
            if caregiverName.textAnswer != nil {
                defaults.set(caregiverName.textAnswer?.alphanumeric, forKey: "helperName")
                defaults.set(true, forKey: "hasHelper")
            } else {
                defaults.set(defaults.string(forKey: "patientName"), forKey: "helperName")
                defaults.set(false, forKey: "hasHelper")
            }
        }
    }
}
