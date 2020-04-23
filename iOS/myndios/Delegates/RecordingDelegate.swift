//
//  RecordingDelegate.swift
//  myndios
//
//  Created by Matthias Hohmann on 08.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation
import RxSwift

/// object that stores EEG data, can be flushed
class EEGRecording: NSObject {
    // Timeseries
    var rawData = [[Double]]()
    var markerData = [Int]()
    var timeStamp = [Int]()
    
    // Meta Data
    var subjectInfo = Dictionary<String, Any>()
    var trialInfo = [(String, Double)]()
    var paradigm: ParadigmModel?
    
    // Live Data
    private var currentMarker: Int = 0
    private var currentTimeStamp: Int = 0
    
    override init() {
        super.init()
        flush()
    }
    
    /// add data to this object
    func appendData(_ data: [Double]) {
        rawData.append(data)
        markerData.append(currentMarker)
        currentMarker = 0
        timeStamp.append(currentTimeStamp)
    }
    
    func setTimeStamp(_ timeStamp: Int) {
        currentTimeStamp = timeStamp
    }
    
    func setMarker(_ marker: Int) {
        currentMarker = marker
    }
    
    /// this can be called before saving
    func checkHealthOfData() throws {
        if rawData.count == 0 || rawData[0].count == 0 {
            throw "No data was recorded"
        }
        
        if markerData.max() == 0 {
            throw "No marker was recorded"
        }
        
        if paradigm == nil {
            throw "No paradigm was set"
        }
    }
    
    /// deletes everything in this object
    func flush() {
        rawData = [[Double]]()
        markerData = [Int]()
        timeStamp = [Int]()
        
        subjectInfo = Dictionary<String, Any>()
        trialInfo = [(String, Double)]()
        paradigm = nil
        
        currentMarker = 0
        currentTimeStamp = 0
    }
}

/// The `RecordingDelegate` is instantiated during EEG recording. It observes the `data` signal from the `DataController` and stores values in a `EEGRecording` object. `markerData` and `paradigm` are collected from the `ScenarioViewController` during recording. Additional `subjectInfo`, like fitting time, is collected during recording.
class RecordingDelegate: NSObject {
    
    // MARK: - Dependencies
    let defaults = UserDefaults.standard
    let nc = NotificationCenter.default
    weak var dataController: DataController! = nil
    weak var scenarioPlayer: ScenarioViewController?
    
    // MARK: - Recording
    private var recording = EEGRecording()
    var isRunning: Bool = false

    // MARK: - Internal
    private var disposeBag = DisposeBag()
    
    /**
     Initialize Storage Delegate Object
     - Attention: Instantiating is necessary to record new data. File handling is done by static functions.
     */
    init(_ dataController: DataController) {
        super.init()
        self.dataController = dataController
    }
    
    /////////////////////////
    // MARK: - Recording
    /////////////////////////
    
    /**
     Start listening to new EEG Data
     - Establishes a connection to the data delegate
     - Appends new EEG data to array, adds current marker(optional) and timestamp to array at that point
     */
    func start() {
        guard !isRunning else {return}
        
        isRunning = true
        scenarioPlayer == nil ? (print("[WARNING] No scenarioPlayer was set, will not record markers.")) : ()

            // Subscribe to Raw Data, append to double array
            dataController.data
                .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
                .subscribe({[recording] data in recording.appendData(data.element!)})
                .disposed(by: disposeBag)
            dataController.timeStamp
                .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
                .subscribe({[recording] data in recording.setTimeStamp(data.element!)})
                .disposed(by: disposeBag)
            scenarioPlayer?.currentMarker.asObservable()
                .subscribe({[recording] data in recording.setMarker(data.element!)}).disposed(by: disposeBag)
            recording.paradigm = scenarioPlayer?.session.paradigm
    }
    
    func finishAndStore() {
        isRunning = false
        disposeBag = DisposeBag()

        do {
            try recording.checkHealthOfData()
            _ = StorageController.shared.storeRecording(recording)
        } catch let error {
            print(error)
        }
        recording.flush()
    }
    
    func eraseRecordedData() {
        isRunning = false
        disposeBag = DisposeBag()
        recording.flush()
    }
    
    func appendSubjectInfo(info: [String: Any]) {
        for item in info {
            recording.subjectInfo[item.key] = item.value
        }
    }
}
