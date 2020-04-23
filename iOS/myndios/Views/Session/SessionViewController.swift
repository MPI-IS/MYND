//
//  SessionViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 25.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import RxSwift

/**
`SessionView` is the container view for all views that are presented during an EEG recording. In terms of EEG data, it instantiates `DataController` with the chosen recording device, `ProcessingDelegate`, and `RecordingDelegate` during initialization. It also instantiates all views that appear during the recording (see above), including an `ErrorView` that is called if something goes wrong, and a `RawDataView` that can be accessed in developer-mode. It collects meta-information during the session, e.g., fitting time (see `logItems`), and handles cancellation, errors, or successful completions (see `stop`). The `setSession` function sets a specific recording scenario and alters `completion` functions if necessary: If the user transitions from one scenario (e.g., rest) to another (e.g., memories), without taken the headset off, all hardware preparation steps are skipped. If the user opts-in for regular instructions, a step is presented that reminds them to enable shortened instructions if they feel comfortable.
 
 # Inherited Properites
 - defaults, nc
 - session
 - sessionStartTime
 - sessionResult
 - isExperimentRunning
 - flowViewController
 
 # Inherited functions
 - setSession
 - goTo Phase
 */
class SessionViewController: MNDSessionVCBase {
    
    /////////////////////////
    // MARK: - Delegates
    
    var dataController: DataController! = nil
    var processingDelegate: ProcessingDelegate! = nil
    var recordingDelegate: RecordingDelegate! = nil
    var scenarioPlayer: ScenarioViewController! = nil
    
    /////////////////////////
    // MARK: - Session Information
    
    // reset after storage
    var fittingTime: Double = 0
    var recordingStartTime: Date!
    var recordingEndTime: Date!
    
    /////////////////////////
    // MARK: - Internal
    private var disposeBag = DisposeBag()
    private var detailCompletion: (() -> ())?
    private var uploadCompletion: (() -> ())?
    
    /////////////////////////
    // MARK: - Factory
    
    static func make(session: ScenarioModel?, shortFitting: Bool = false) -> SessionViewController {
        let viewController = SessionViewController()
        // first set the session
        viewController.setSession(session, shortFitting: shortFitting)
        // then set everything else
        viewController.commonInit()
        return viewController
    }
    
    private func commonInit() {
        // Initialize all delegates
        var isAuxEnabled = false
        var device = Devices.oscillator
        defaults.bool(forKey: "isAuxEnabled") ? (isAuxEnabled = session.auxChannel!) : ()
        defaults.string(forKey: "device") == "Muse" ? (device = .muse) : ()
        dataController == nil ? (dataController = DataController.shared) : ()
        dataController.setDataSource(to: device, auxChannel: isAuxEnabled)
        processingDelegate = ProcessingDelegate(dataController)
        recordingDelegate = RecordingDelegate(dataController)
        
        // Initialize regular session flow
        var sessionFlow = [MNDSessionStep: UIViewController]()
        sessionFlow[.detail] = DetailViewController.make(self, completion: detailCompletion)
        sessionFlow[.boarding] = StepViewController.make(self, mode: "Start") {[weak self] in self?.goTo(phase: .noise)}
        sessionFlow[.noise] = FittingViewController.make(self, mode: .noise) {[weak self] in self?.goTo(phase: .fitting)}
        sessionFlow[.fitting] = FittingViewController.make(self, mode: .initialFitting) {[weak self] in self?.goTo(phase: .scenario)}
        sessionFlow[.scenario] = ScenarioViewController.make(self)
        sessionFlow[.pause] = PauseViewController.make(self)
        sessionFlow[.checkUp] = FittingViewController.make(self, mode: .checkUp) {[weak self] in self?.goTo(phase: .scenario)}
        
        // Initialize clean-up after subjects decide to end a session
        sessionFlow[.upload] = UploadViewController.make(TransferController.shared, completion: uploadCompletion)
        sessionFlow[.finish] = StepViewController.make(self, mode: "Finish", completion: {[weak self] in self?.navigationController?.popToRootViewController(animated: true)})
        
        // Initialize special views that are not part of the typical procedure
        sessionFlow[.cancel] = StepViewController.make(self, mode: "Cancel", completion: {[weak self] in self?.navigationController?.popToRootViewController(animated: true)})
        sessionFlow[.error] = NotificationViewController.make(self, type: .error, completion: {[weak self] in self?.navigationController?.popToRootViewController(animated: true)})
        sessionFlow[.introCompleted] = StepViewController.make(self, mode: "introCompleted", completion: {[weak self] in self?.goTo(phase: .finish)})
        sessionFlow[.rawData] = RawDataViewController.make(self)
        flowVC.sessionFlow = sessionFlow
        
        // Add scenario controller to the recordingDelegate for markers
        recordingDelegate.scenarioPlayer = sessionFlow[.scenario] as? ScenarioViewController
    }
    
    /////////////////////////
    // MARK: - View Control
    
    /// Subscribe to device states, configure navigation, load initial View
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(endSession))

        dataController.deviceStateChanged
            .subscribe({[weak self] changed in (changed.element!) ? (self?.deviceDidChangeState()) : ()}).disposed(by: disposeBag)
        goTo(phase: .detail)
    }
    
    // Dispose Bag, stop speech if any
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposeBag = DisposeBag()
        TTSController.shared.stop()
    }
    
    /////////////////////////
    // MARK: - Session Control
    
    func start(recording: Bool = false) {
        // make sure everything was initialized
        guard processingDelegate != nil,
            session != nil,
            uploadCompletion != nil else {return}
        
        isExperimentRunning = true
        dataController.start()

        // Start recording data
        if recording {
            recordingDelegate.start()
            recordingStartTime == nil ? (recordingStartTime = Date()) : ()
        }
    }
    
    /// this is were results are handled, data is stored, the study is advanced, and a time out date is set
    func stop(with reason: MNDSessionEndReason) {
        processingDelegate.stop()

        // Stop recording data, erase or store. Disconnect from headset if error or cancel
        switch reason {
        case .error:
            StudyController.shared.loadOrOverrideCurrentStudyProgress()
            dataController.stop()
            recordingDelegate.isRunning ? recordingDelegate.eraseRecordedData() : ()
            isExperimentRunning = false
            goTo(phase: .error)
        case .cancel:
            StudyController.shared.loadOrOverrideCurrentStudyProgress()
            dataController.stop()
            recordingDelegate.isRunning ? recordingDelegate.eraseRecordedData() : ()
            isExperimentRunning = false
            goTo(phase: .cancel)
        case .complete:
            logItems()
            sessionResult = .didFinishBlock
            StudyController.shared.currentStudy!.setCurrentDayTimeOut(to: Date().addingTimeInterval(defaults.double(forKey: "timeOutTimeInterval")))
            defaults.set(defaults.integer(forKey: "currentRunIndex") + 1, forKey: "currentRunIndex")
            recordingDelegate.isRunning ? (DispatchQueue.main.async { [weak self] in
                self?.recordingDelegate.finishAndStore()
            } ) : ()
            
            // Advance indices and check the result of this session
            if session.scenarioCompleted {
                sessionResult = .didFinishScenario
                _ = StudyController.shared.currentStudy!.advanceSession()
                
                // check for day completion
                if StudyController.shared.currentStudy!.checkCompletion().day {
                    sessionResult = .didFinishDay
                }
            }
            StudyController.shared.saveCurrentStudyProgress()
            goTo(phase: .pause)
        }
    }
    
    /////////////////////////
    // MARK: - User Interaction
    
    /// a subject cancels the study
    @objc func endSession(force: Bool = false) {
        
        isExperimentRunning = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        // Erase existing progress
        StudyController.shared.loadOrOverrideCurrentStudyProgress()
        recordingDelegate.isRunning ? recordingDelegate.eraseRecordedData() : ()
        processingDelegate.isRunning ? processingDelegate.stop() : ()
        dataController.stop()
        
        if sessionResult != .none {
            TransferController.shared.uploadPending()
            goTo(phase: .upload)
        } else {
            stop(with: .cancel)
        }
    }
    
    /// raw data, only in dev mode
    @objc func showRawData() {
        flowVC.goTo(phase: .rawData)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "OK", style: .done, target: self, action: #selector(doneWithRawData))
    }
    
    @objc func doneWithRawData() {
        flowVC.goTo(phase: currentPhase)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Raw Data", style: .plain, target: self, action: #selector(showRawData))
    }
    
    /////////////////////////
    // MARK: - Internal
    
    /// respond to device state changes
    func deviceDidChangeState() {
        if (dataController.deviceState[.disconnected]! || dataController.deviceState[.batteryLow]!) && isExperimentRunning {
            print("headset was disconnected")
            BannerController.shared.makeGeneralAnnouncement(forSignal: .disconnected)
            stop(with: .error)
        }
        
        if dataController.deviceState[.connected]! && defaults.bool(forKey: "isDeveloperModeEnabled") {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Raw Data", style: .plain, target: self, action: #selector(showRawData))
        }
    }
    
    /// set a given session, alter completion functions if necessary
    func setSession(_ session: ScenarioModel?, shortFitting: Bool = false) {
        guard let session = session,
            session.type == .recording else {return}
        super.setSession(session: session)
        
        // if the fitting is short, go straight to checkUp after detail view. If the user transitions from one scenario (e.g., rest) to another (e.g., memories), without taken the headset off, all hardware preparation steps are skipped.
        if shortFitting {
            detailCompletion = {[weak self] in self?.goTo(phase: .checkUp); self?.start()}
        } else {
            detailCompletion = {[weak self] in self?.goTo(phase: .boarding); self?.start()}
        }
        if let dv = (flowVC.sessionFlow[.detail] as? DetailViewController) {
            dv.completion = detailCompletion
        }
        // If the user opts-in for regular instructions, a step is presented that reminds them to enable shortened instructions if they feel comfortable.
        if defaults.bool(forKey: "isShortInstructionEnabled") {
            uploadCompletion = {[weak self] in self?.goTo(phase: .finish)}
        } else {
            uploadCompletion = {[weak self] in self?.goTo(phase: .introCompleted)}
        }
        if let uc = (flowVC.sessionFlow[.upload] as? UploadViewController) {
            uc.completion = uploadCompletion
        }

    }
    
    /// log additional subject info, to be stored in the HDF5 file
    fileprivate func logItems() {
        guard recordingStartTime != nil && recordingDelegate != nil else {
            return
        }
        
        var items = [String: Any]()
        
        // Log time for recording and fitting
        recordingEndTime = Date()
        let recordingTime =  Double(recordingEndTime.timeIntervalSince(recordingStartTime))
        items["recordingTime"] = recordingTime
        items["recordingStartTime"] = recordingStartTime.timeStamp()
        items["recordingEndTime"] = recordingEndTime.timeStamp()
        items["sessionStartTime"] = sessionStartTime.timeStamp()
        items["fittingTime"] = fittingTime

        // Reset times
        recordingStartTime = nil
        recordingEndTime = nil
        fittingTime = 0
        
        // Log other session information
        items["device"] = dataController.device!.rawValue
        items["samplingRate"] = dataController.samplingRate!
        items["channelCount"] = dataController.channels!.count
        items["channelNames"] = dataController.channels!
        items["subjectID"] = defaults.string(forKey: "uuid")
        items["sessionID"] = session.index
        items["runID"] = defaults.integer(forKey: "currentRunIndex")
        items["day"] = session.day
        items["locale"] = NSLocale.autoupdatingCurrent.languageCode
        recordingDelegate.appendSubjectInfo(info: items)
    }
}
