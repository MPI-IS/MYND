//
//  FittingViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 23.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import RxSwift
import UIKit
import Surge
import M13Checkbox

enum ProgressViewVisibility: String {
    case idle
    case front
    case back
    case all
}

enum FittingMode: String {
    case noise
    case initialFitting
    case checkUp
}

/// struct for displayed fitting values
struct FittingValue {
    var complete: Bool = false
    var threshold: CGFloat {
        get{return _threshold}
        set {
            complete = false
            _threshold = newValue
        }
    }
    var value: CGFloat {
        get {
            if complete {
                return 100
            }
            return (_value / _threshold) * 100
        }
        set {
            _value = newValue
            if newValue >= _threshold && complete == false {
                complete = true
            }
        }
    }
    
    private var _value: CGFloat = 0
    private var _threshold: CGFloat = 100

}

/**
The `FittingView` helps subject to check for noisy environments, fit the headset, and check the connectivity between blocks. It shares several similarities in the way it handles preparation steps with `StepModel` objects, you may refer to "Step view" for more information. Here, `FittingMode` represents the `mode` of this view. The three differences are its layout, its response to signal quality estimates sent by `ProcessingDelegate`, and execution of completion *functions*.

Fitting view uses 4 (or 5, if the aux electrode is enabled) `SignalQualityRingView`s to display signal quality in real-time. They can be in `idle` state, in which case they are just presented as outlines, `inactive`, where they get updated in gray color, and `active`, where they reflect signal quality with red, yellow, and green colors. The also feature a checkbox that can be enabled to display when progress reaches 100. The `FittingMode` and completion functions, defined in `completionIfAny()`, mainly control which signal quality ring views are visible at a time to guide subjects efficiently.

Fitting view subscribes to signal quality updates from `ProcessingDelegate` and calls `updateProgress` whenever it receives new values. Similar to `StepView`, if all steps were executed and requirements were fulfilled (in this case 100% signal quality, 75% after 3 minutes), fitting view finished and transitions to the next view.
*/
class FittingViewController: UIViewController {
  
    /////////////////////////
    // MARK: - Interface Builder Outlets
    
    @IBOutlet var eegProgressViews: [SignalQualityRingView]!
    @IBOutlet weak var visualInstructionView: MNDVisualInstructionView!
    @IBOutlet weak var instructionTextView: UITextView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var successCheckBox: M13Checkbox!
    
    /////////////////////////
    // MARK: - Internal
    
    // Dependencies
    private weak var sessionVC: SessionViewController! = nil
    private let defaults = UserDefaults.standard
    private let nc = NotificationCenter.default
    
    // Data
    private var steps = [StepModel]()
    private var stepsIterator: Int = 0
    
    // Fitting
    private var fittingValues: [FittingValue]!
    private var fittingCompleted: Bool = false
    private var startTime: DispatchTime! = nil // used to compute fitting time
    private var mode: FittingMode!
    private var timeOut: Timer?
    private var disposeBag = DisposeBag()
    
    // Completion
    private var completion: (()->())?
    
    /////////////////////////
    // MARK: - Factory
    
    static func make(_ sessionVC: SessionViewController, mode: FittingMode = .initialFitting , completion: (()->())? = nil) -> FittingViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Fitting") as! FittingViewController

        viewController.sessionVC = sessionVC
        viewController.mode = mode
        viewController.completion = completion
    
        return viewController
    }
    
    /////////////////////////
    // MARK: - View Control
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Visuals
        successCheckBox.stateChangeAnimation = .bounce(.fill)
        successCheckBox.tintColor = UIColor.MP_Green
        
        // Instructions
        if defaults.bool(forKey: "isShortInstructionEnabled") {
            steps = DocumentController.shared.loadShortSteps(for: mode.rawValue)
        } else {
            steps = DocumentController.shared.loadSteps(for: mode.rawValue)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reset Fitting
        fittingValues = Array<FittingValue>(repeating: FittingValue(), count: sessionVC.dataController.channels!.count)

        stepsIterator = 0
        fittingCompleted = false
        for state in [DeviceStates.goodSignal, DeviceStates.goodSignalFront, DeviceStates.goodSignalBack] {
            sessionVC.dataController.dataSource(nil, didChangeStateTo: state, toBool: false)
        }
        
        // Connect to device states
        sessionVC.dataController.deviceStateChanged
            .subscribe({[weak self] changed in (changed.element!) ? (self?.updateButton()) : ()})
            .disposed(by: disposeBag)
        
        // Set visuals
        setProgressViews(to: .idle)
        successCheckBox.setCheckState(.unchecked, animated: false)
        switch mode! {
        case .noise:
            setProgressViews(to: .all)
            eegProgressViews.forEach {$0.setOptionalImage(#imageLiteral(resourceName: "Lightning")); $0.isCheckboxActivated = false}
        case .initialFitting:
             setProgressViews(to: .front)
             eegProgressViews.forEach {$0.setOptionalImage(#imageLiteral(resourceName: "Wave"))}
        case .checkUp:
            setProgressViews(to: .all)
            eegProgressViews.forEach {$0.setOptionalImage(#imageLiteral(resourceName: "Wave"))}
        }
        instructionTextView.text = ""
        
        // Start taking the fitting time
        startTime == nil ? (startTime = DispatchTime.now()) : ()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startProcessing()
        updateStep()
    }
    
    private func startProcessing() {
        switch mode! {
        case .initialFitting, .checkUp:
            //Subscribe to fitting values
            sessionVC.processingDelegate.start(mode: .signalQuality)
        case .noise:
            sessionVC.processingDelegate.start(mode: .noiseDetection)
        }
        sessionVC.processingDelegate.avgSignalQuality
            .subscribe({[weak self] avgSignalQuality in self?.updateProgress(avgSignalQuality.element!)})
            .disposed(by: disposeBag)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionVC.processingDelegate.stop()
        visualInstructionView.clear()
        disposeBag = DisposeBag()
        TTSController.shared.stop()
        timeOut?.invalidate()
    }
    
    // in order to get a true circle, this needs to be done here
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        visualInstructionView.makeCircular()
        successCheckBox.makeCircular()
    }
    
    /////////////////////////
    // MARK: - Fitting Step Control
    
    func updateStep() {
        // make sure that there is another step to execute, otherwise finish
        guard stepsIterator < steps.count else {completion?();return}

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
        
        step.instruction = step.instruction.withFilledPlaceholders(withOptionalArguments: placeholders)
        
        instructionTextView.pushText(step.instruction)
        instructionTextView.centerVertically()
        instructionTextView.scrollRangeToVisible(NSRange(location:0, length:0))
        instructionTextView.flashScrollIndicators()
        
        // If a picture is attached to the step, load it
        if let picture = step.pictureName {
            visualInstructionView.set(visualInstructionString: picture)
        } else {
           visualInstructionView.clear()
        }
        TTSController.shared.say(instructionTextView.text!)
        updateButton()
        
        
        // Time Out handling
        if timeOut != nil {
            timeOut?.invalidate()
            timeOut = nil
        }
        
        if step.timeOut != nil {
            print("timerStarted")
            timeOut = Timer.scheduledTimer(withTimeInterval: step.timeOut!, repeats: false, block: {[weak self] _ in self?.stepDidTimeOut()})
        }
        
        
    }
    
    func completionIfAny() {
        guard stepsIterator < steps.count else {return}
        if let completion = steps[stepsIterator].completion {
            switch completion {
            case .activateFront:
                setProgressViews(to: .front)
            case .activateBack:
                setProgressViews(to: .back)
            case .success:
                successCheckBox.setCheckState(.checked, animated: true)
            default:
                break
            }
        }
    }
    
    /////////////////////////
    // MARK: - Fitting Progress
   
    func updateProgress(_ progress: [Double]) {
        guard !fittingCompleted else {return}

        var didCompleteFitting = true
        for (c,n) in progress.enumerated() {
            // Set fitting values, as constraint by these conditions
            fittingValues[c].value = CGFloat(n)
            fittingValues[c].complete ? () : (didCompleteFitting = false)
            eegProgressViews.first(where: {$0.tag == c+1})?.startProgress(to: fittingValues[c].value, duration: 0.3)

            // Send signals about good signals where applicable
            if [Double(fittingValues[0].value),Double(fittingValues[3].value)].min()! >= 100.0 {
            sessionVC.dataController.dataSource(nil, didChangeStateTo: .goodSignalBack)
                
            }
            // Send signals about good signals where applicable
            if [Double(fittingValues[1].value),Double(fittingValues[2].value)].min()! >= 100.0 {
                sessionVC.dataController.dataSource(nil, didChangeStateTo: .goodSignalFront)
            }
        }
        //check for completion
        if didCompleteFitting {
            fittingCompleted = true
            logItems()
            sessionVC.dataController.dataSource(nil, didChangeStateTo: .goodSignal)
        }
        
    }
    
    @IBAction func nextInstruction(_ sender: UIButton) {
        completionIfAny()
        TTSController.shared.stop()
        stepsIterator += 1
        updateStep()
    }
    
    /////////////////////////
    // MARK: - Visuals
    
    fileprivate func setProgressViews(to state: ProgressViewVisibility) {
        switch state {
        case .idle:
            for i in 1...sessionVC.dataController.channels!.count {
                (i <= eegProgressViews.count) ? (toggleProgressViewStatus(ofElectrode: i, to: .idle)) : ()
            }
        case .front:
            toggleProgressViewStatus(ofElectrode: 1, to: .idle)
            toggleProgressViewStatus(ofElectrode: 4, to: .idle)
            toggleProgressViewStatus(ofElectrode: 2, to: .active)
            toggleProgressViewStatus(ofElectrode: 3, to: .active)
        case .back:
            toggleProgressViewStatus(ofElectrode: 1, to: .active)
            toggleProgressViewStatus(ofElectrode: 4, to: .active)
            toggleProgressViewStatus(ofElectrode: 2, to: .inactive)
            toggleProgressViewStatus(ofElectrode: 3, to: .inactive)
        case .all:
            for i in 1...sessionVC.dataController.channels!.count {
                (i <= eegProgressViews.count) ? (toggleProgressViewStatus(ofElectrode: i, to: .active)) : ()
            }
        }
    }
    
    fileprivate func toggleProgressViewStatus(ofElectrode number: Int, to state: SignalQualityRingViewState) {
        let view = eegProgressViews.first(where: {$0.tag == number})!
        if view.isHidden {
            view.isHidden = false
        }
        view.setState(to: state)
    }
 
    @IBAction func sayAgain(_ sender: UITapGestureRecognizer) {
        TTSController.shared.say(instructionTextView.text)
    }
    
    fileprivate func updateButton() {
        
        let step = steps[stepsIterator]
        let button = nextButton!
        let state = sessionVC.dataController.deviceState
        
        // if there is a completion signal attached, check if it has been fullfilled, otherwise disable user interaction
        if let signal = step.completionSignal {
            // if signal was fullfilled, allow progression
            if state[signal]! && !step.success{
                step.success = true
                BannerController.shared.makeGeneralAnnouncement(forSignal: signal)
                UIView.animate(withDuration: 0.5) {
                    button.layer.backgroundColor = UIColor.MP_Blue.cgColor
                }
                button.isEnabled = true
            // if signal was not fullfilled, disable user input
            } else if !step.success {
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
    }
    
    /// drop signal quality requirement to 75% after three minutes to keep subjects motivated
    func stepDidTimeOut() {
        print("didTimeOut")
        nc.postBanner(message: NSLocalizedString("Making it easier", comment: ""), style: "devError")
        for i in fittingValues.indices {
            fittingValues[i].threshold = 75
        }
    }

    /////////////////////////
    // MARK: - Other
    
    fileprivate func logItems() {
        let endTime = DispatchTime.now()
        let fittingTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        sessionVC.fittingTime = fittingTime
        startTime = nil
    }
}
