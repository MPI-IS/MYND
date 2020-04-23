//
//  ScenarioViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 20.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import RxSwift
import UIKit
import Surge

/**
 After fitting completed, `ScenarioView` contains the actual display of experimental prompts and recording of EEG data. Please refer to "model -> EEG recordings" for details on how scenarios are structured. Scenario view is essentially a timed text display. Scenarios are presented as follows:
 1. `start`: get the trial at the next global index, always reset phase to zero in case the subject cancelled a recording somewhere in between before.
 2. `updateVisuals`: set the prompt, set feedback if desired (not implemented), send the current `marker` to the `RecordingDelegate`, and set a *timer* with the duration of this phase, after which the phase count progresses. If duration is zero, the current phase is *variable* in lengthL: Listen to `TTSController` with `ttsChanged`, and proceed to the next phase once it is done talking.
 3. `nextPhase`: called when the timer runs out. Disables the timer and calls `updatePhase` (This two step update was done to enable developers to advance the phase by just tapping the screen in dev-mode).
 4. `updatePhase`: call `ScenarioModel->advance()` to move to the next phase. Scenario model will set a flag if we reached the end of the trial, or the end of the whole scenario. The trial index is tracked globally to start at the right block of a scenario, and locally, to check if the current amount of trials equals the `checkAtIndex` property of `ScenarioModel`. If this is true, a block was completed and the signal quality check up is triggered.
 5. `updateVisuals`: see 2.
 6. If all trials of the block were completed `finishRunAndStore` will stop the execution and inform the container `SessionView` that data was recorded successfully. The `SessionView` will in turn check if the whole scenario was completed, and alter the text in the upcoming `PauseView`.

 Note: Scenario view instantiates `FeedbackView` during initialization, which covers the whole screen during execution. This view was designed to display feedback as a slowly moving waveform, but was not used at the time of development. It is left in the code as blueprint for future extensions.
 */
class ScenarioViewController: UIViewController, TTSListener {
    
    /////////////////////////
    // MARK: - Dependencies
    
    weak var sessionVC: SessionViewController! = nil
    var session: ScenarioModel! = nil
    
    let defaults:UserDefaults = UserDefaults.standard
    
    /////////////////////////
    // MARK: - Interface Builder Outlets
    
    @IBOutlet weak var instruction: UILabel!
    @IBOutlet weak var progress: UIProgressView!
    
    /////////////////////////
    // MARK: - Public Properties
    var currentMarker = BehaviorSubject<Int>(value: 0)
    var initialTrialIndex: Int = 0
    
    /////////////////////////
    // MARK: - Internal Properties
    
    private weak var feedbackViewController: FeedbackViewController!
    
    private var timer: DispatchSourceTimer?
    private var variablePhase: Bool = false
    private var disposeBag = DisposeBag()
    
    private let startTime: DispatchTime! = nil
    
    /////////////////////////
    // MARK: - Factory
    
    static func make(_ sessionVC: SessionViewController) -> ScenarioViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Scenario") as! ScenarioViewController
        viewController.sessionVC = sessionVC
        return viewController
    }
    
    /////////////////////////
    // MARK: - View Control
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate feedback view controller
        feedbackViewController = self.children.first! as? FeedbackViewController
        feedbackViewController.feedbackDelegate = FeedbackController(processingDelegate: sessionVC.processingDelegate)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(skipPhase(sender:)))
        tap.numberOfTapsRequired = 1 // Default value
        feedbackViewController.feedbackView.isUserInteractionEnabled = true
        feedbackViewController.feedbackView.addGestureRecognizer(tap)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // take current session
        session = sessionVC.session
        TTSController.shared.listener = self
        // check volume. If it's too low, show an alert before starting. If it's OK just start
        let volume = TTSController.shared.checkVolume()
        if volume < 0.3 {
            let alert = UIAlertController(title: NSLocalizedString("#lowVolumeTitle#", comment: ""), message: NSLocalizedString("#lowVolumeText#", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) {
                [weak self] _ in
                self?.start()
                })
            present(alert, animated: true, completion: nil)
        } else {
           start()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TTSController.shared.listener = nil
        stop()
    }
    
    /////////////////////////
    // MARK: - Scenario Flow
    
    fileprivate func getLocalTrialIndex() -> Int {
        return session.getTrial().index - initialTrialIndex
    }
    
    func start() {
        session.getTrial().object!.resetPhase() // always go back to the first phase of the current trial when the view comes back
        initialTrialIndex = session.getTrial().index
        progress.setProgress(0, animated: false)
        
        sessionVC.start(recording: true)
        if session.feedback! {
            sessionVC.processingDelegate.start(mode: .noiseDetection)
            feedbackViewController.startFeedback()
        }
        updateVisuals()
    }
    
    fileprivate func stop() {
        disposeBag = DisposeBag()
        TTSController.shared.listener != nil ? (TTSController.shared.listener = nil) : ()
        if session.feedback! {
            feedbackViewController.stopFeedback()
        }
        timer?.cancel()
        feedbackViewController.instructionView.stopCountdown()
    }
    
    fileprivate func finishRunAndStore() {
        stop()
        sessionVC.stop(with: .complete)
        
        // If the whole session was completed, it will say so in the pause controller
        sessionVC.goTo(phase: .pause)
    }
    
    func updatePhase(){
        
        // Move forward with the phase index. If it doesn't exist, we have finished a trial
        session.advance()
        progress.setProgress(Float(getLocalTrialIndex() + 1) / Float(session.checkAtIndex!), animated: true)
        
        // If the scenario was completed or it is time to check the signal quality, finish run and store
        if session.scenarioCompleted || getLocalTrialIndex() >= session.checkAtIndex! {
            finishRunAndStore()
            return
        }
        updateVisuals()
    }
        
    func updateVisuals() {
        let phase = session.getTrial().object!.getPhase().object!
        DispatchQueue.main.async {
            self.currentMarker.onNext(phase.marker)
            self.session.feedback! ? (self.feedbackViewController.updateClass(phase.feedback, withTimeout: phase.duration)) : ()
            self.instruction.pushText(phase.text)
            // If the duration is > 0 use this as timer and set countdown, otherwise wait until TTS is done talking and handle it with delegate function
            if phase.duration > 0 {
                self.nextPhase(after: phase.duration)
            } else {
                self.variablePhase = true
            }
            TTSController.shared.say(phase.text, force: true)
        }
    }
    
    func nextPhase(after delay: Double) {
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.main)
        timer?.setEventHandler(handler: { [weak self] in self?.updatePhase()})
        timer?.schedule(deadline: .now() + delay, leeway: .seconds(0))
        timer?.activate()
    }
    
    func ttsChanged(toState state: TTSStates, withText text: String) {
        if variablePhase && state == .finished && text == instruction.text! {
            nextPhase(after: 1.0)
            variablePhase = false
        }
    }
    
    /////////////////////////
    // MARK: - User Interaction
    
    @objc func skipPhase(sender: UITapGestureRecognizer) {
        if defaults.bool(forKey: "isDeveloperModeEnabled") && (getLocalTrialIndex() < session.checkAtIndex!) {
            variablePhase = false
            sessionVC.isExperimentRunning ? nextPhase(after: 0.0) : ()
        }
    }

}
