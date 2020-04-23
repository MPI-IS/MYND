//
//  StepViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 29.01.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import RxSwift

/// The `StepView` is used to display text and an optional picture or video for hardware preparation and cleanup. The steps that are to be displayed are defined by the `mode` parameter: A string that is looked up by the `DocumentController` in the steps JSON file to find the right set of instructions. At the time of development, `steps_en.json` included `Start` for hardware preparation, `noise` for electromagnetic noise detection, `initialFitting`, `checkUp` for fitting between blocks, `introCompleted` to remind subjects to enable shortened instructions after their first recording, `Finish` for clean-up after recording, `QuestionnaireFinish` for clean-up after questionnaires, and `cancel` when subjects cancel the current session. `noise`, `initialFitting`, and `checkUp` are meant to be displayed within the `FittingView`.
class StepViewController: UIViewController {
    
    /////////////////////////
    // MARK: - Dependencies
    
    weak var sessionVC: MNDSessionVCBase!
    weak var recordingVC: SessionViewController?
    let nc = NotificationCenter.default
    
    /////////////////////////
    // MARK: - Interface Builder Outlets
    
    @IBOutlet weak var visualInstructionView: MNDVisualInstructionView!
    @IBOutlet weak var instructionLabel: UITextView!
    @IBOutlet weak var nextButton: UIButton!
    
    /////////////////////////
    // MARK: - Internal Properties
    
    fileprivate var steps = [StepModel]()
    fileprivate var stepsIterator: Int = 0
    fileprivate var mode: String! = nil
    fileprivate var completion: (()->())?
    fileprivate var _disposeBag = DisposeBag()
    fileprivate let defaults = UserDefaults.standard
    
    // some steps may include a time out and cancel the session once that time passed, in order to not frustate subjects or have them stuck
    fileprivate var timeOut: Timer?
    
    /////////////////////////
    // MARK: - Factory
    
    static func make( _ sessionVC: MNDSessionVCBase, mode: String = "Start", completion: (()->())? = nil) -> StepViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Step") as! StepViewController
        viewController.sessionVC = sessionVC
        if sessionVC.session.type == .recording {
            viewController.recordingVC = sessionVC as? SessionViewController
        }
        
        viewController.mode = mode
        viewController.completion = completion
        return viewController
    }
    
    /////////////////////////
    // MARK: - View Control
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if defaults.bool(forKey: "isShortInstructionEnabled") {
            steps = DocumentController.shared.loadShortSteps(for: mode)
        } else {
           steps = DocumentController.shared.loadSteps(for: mode)
        }
        
        // this is subscribing to changes in the device state, and enables progression if the right state changed to true
        recordingVC?.dataController.deviceStateChanged.subscribe({[weak self] changed in (changed.element!) ? (self?.updateButton()) : ()}).disposed(by: _disposeBag)
        instructionLabel.text = "" // remove blind text
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateInstruction() // needs to be in viewDidAppear for the TTS to catch up
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _disposeBag = DisposeBag()
        visualInstructionView.clear()
        TTSController.shared.stop()
        timeOut?.invalidate()
    }
    
    /////////////////////////
    // MARK: - Instruction Flow
    
    func updateInstruction() {
        if stepsIterator < steps.count {
            let step = steps[stepsIterator]
        
            var placeholders = [String: String]()
            if step.instruction.contains("#blockDuration#") {
                placeholders["#blockDuration#"] = "\(Int((sessionVC.session.getDuration().block / 60).rounded(.up)))"
            }
            
            // check the time out and replace placeholder. If no countdown is happening, remove it
            if StudyController.shared.currentStudy!.checkForDayTimeOut().state == .wait {
                let string = NSLocalizedString("#youHaveTimeRemaining#", comment: "").replacingOccurrences(of: "%s", with: StudyController.shared.currentStudy!.checkForDayTimeOut().timeInterval.stringFromTimeInterval())
                placeholders["#youHaveTimeRemaining#"] = string
            } else {
                placeholders["#youHaveTimeRemaining#"] = ""
            }
            
            // replace placeholders
            step.instruction = step.instruction.withFilledPlaceholders(withOptionalArguments: placeholders)
            
            instructionLabel.pushText(step.instruction)
            instructionLabel.centerVertically()
            instructionLabel.scrollRangeToVisible(NSRange(location:0, length:0))
            instructionLabel.flashScrollIndicators()
            
            // If a picture is attached to the step, load it
            if let picture = steps[stepsIterator].pictureName {
                visualInstructionView.set(visualInstructionString: picture)
            } else {
                visualInstructionView.clear()
            }
            
            TTSController.shared.say(instructionLabel.text!)
            updateButton()
        }
        else {
            // if the last step was shown, proceed to the next view
            view.isUserInteractionEnabled = false
            completion?()
        }
    }
    
    /// `StepView` can respond to completion signals. These signals can be anything in the `DeviceState` enum in `DataController`, e.g., `connected`, if the headset was connected. The `DataController`, and in turn the specific `DataSource` are responsible for sending these signals when appropriate. Subjects will be unable to complete the step (in this case `turnOn`) until this signal was sent. To trigger this behavior, a `completionSignal` String is set in the JSON with the same name. This is then converted by the `DocumentController->evaluteSignal` function to its enum value, and attached to the `StepModel` object. See "model -> questionnaires" for more information.
    fileprivate func updateButton() {
        
        if timeOut != nil {
            timeOut?.invalidate()
            timeOut = nil
        }
        
        let step = steps[stepsIterator]
        let button = nextButton!
        
        // if there is a completion signal attached, check if it has been fullfilled, otherwise disable user interaction
        if sessionVC.session.type == .recording,
            let state = recordingVC?.dataController.deviceState,
            let signal = step.completionSignal {
            // if signal was fullfilled, allow progression
            if state[signal]! {
                // `StepView` can trigger a banner announcement if a step was completed successfully. The sent signal is forwarded to `BannerController`, which looks up and displays the appropriate message with `makeGeneralAnnouncement`. This was implemented to make it easier to notice when the headset was found and connected successfully, for example.
                BannerController.shared.makeGeneralAnnouncement(forSignal: signal)
                UIView.animate(withDuration: 0.5) {
                    button.layer.backgroundColor = UIColor.MP_Blue.cgColor
                }
                button.isEnabled = true
            // if signal was not fullfilled, disable user input
            } else {
                UIView.animate(withDuration: 0.5) {
                    button.layer.backgroundColor = UIColor.MP_Grey.cgColor
                }
                defaults.bool(forKey: "isDeveloperModeEnabled") ? (): (button.isEnabled = false)
            }
        // if there is no completion signal, just allow the user to continue
        } else {
            UIView.animate(withDuration: 0.5) {
                button.layer.backgroundColor = UIColor.MP_Blue.cgColor
            }
            button.isEnabled = true
        }
        
        // if there is a custom title, set it
        if button.isEnabled {
            step.buttonSuccessTitle != nil ? (button.setTitle(step.buttonSuccessTitle!, for: .normal)) : (button.setTitle(NSLocalizedString("#nextStep#", comment: ""), for: .normal))
        } else {
            step.buttonTitle != nil ? (button.setTitle(step.buttonTitle!, for: .normal)) : (button.setTitle(NSLocalizedString("#nextStep#", comment: ""), for: .normal))
        }
        
        if step.timeOut != nil {
            timeOut?.invalidate()
            timeOut = Timer.scheduledTimer(withTimeInterval: step.timeOut!, repeats: false, block: {[weak self] _ in self?.stepDidTimeOut()})
        }
    }
    
    /// send subjects back home if a step has a time out attached to it, and it timed out
    func stepDidTimeOut() {
        nc.postBanner(message: NSLocalizedString("#stepDidTimeOut#", comment: ""), style: "error", say: true)
    }
    
    /////////////////////////
    // MARK: - User Interaction
    
    @IBAction func sayAgain(_ sender: UITapGestureRecognizer) {
            TTSController.shared.say(instructionLabel.text)
    }
    
    @IBAction func nextInstruction(_ sender: UIButton) {
        stepsIterator += 1
        TTSController.shared.stop()
        updateInstruction()
    }
}

