//
//  DataController.swift
//  myndios
//
//  Created by Matthias Hohmann on 01.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import Accelerate
import Foundation
import RxSwift

/**
 Through this protocol, the data controller is injected as a dependency into the current data source to handle incoming data or a change of the devices state.
 */
protocol DataControllerCallBack: class {
    func dataSource(_ dataSource: DataSource?, didReceiveData data: [Double], withTimeStamp timeStamp: Int)
    func dataSource(_ dataSource: DataSource?, didChangeStateTo state: DeviceStates, toBool bool: Bool)
}

// Data Sources need to conform to this protocol
protocol DataSource {
    var dataController: DataControllerCallBack? {get set}
    var type: Devices {get}
    var battery: Double {get}
    var channels: [String] {get}
    var samplingRate: Int {get}
    func setChannels(count: Int)
    func start()
    func stop()
}

enum DeviceStates: String {
    case unknown
    case found
    case connected
    // note that checking whether the headset is on someones head is a specific Muse feature. If this was to be used with a different headset, you may either need to implement this functionality yourself or leave it out of the hardware preparation steps.
    case onHead
    case disconnected
    case complete
    case goodSignalFront
    case goodSignalBack
    case goodSignal
    case batteryLow
    // this is necessary to create a dictionary with all available states
    static let allValues = [unknown,found,connected,onHead,disconnected,complete,goodSignalFront,goodSignalBack, goodSignal, batteryLow]
}

// This needs to be extended if a new data source is created
enum Devices: String {
    case muse
    case oscillator
}

/**
 The `DataController` manages incoming data from the employed `DataSource` and has access to device-information like battery and sampling rate. Interfacing with a particular device is realized with in a separate controller that conforms to the `DataSource` protocol. `data`, `timestamp`, and `deviceStateChanged` are the main variables that can be observed by other functions.
 */
class DataController: NSObject, DataControllerCallBack {
    
    // singleton
    static let shared = DataController()
    
    private override init() {
        super.init()
    }
    
    private let nc = NotificationCenter.default
    
    // Data Source Parameters
    var dataSource: DataSource?
    var deviceState = [DeviceStates: Bool]()
    var deviceStateChanged = PublishSubject<Bool>()
    
    var samplingRate: Int? {get {return dataSource?.samplingRate}}
    var channels: [String]? {get {return dataSource?.channels}}
    var battery: Double? {get {return dataSource?.battery}}
    var device: Devices? {get {return dataSource?.type}}
    
    // Data to be observed via RxSwift
    var data = BehaviorSubject<[Double]>(value: [0])
    var timeStamp = BehaviorSubject<Int>(value: 0)
    
    var isRunning: Bool = false
    
    // set a new data source with this function
    func setDataSource(to source: Devices, auxChannel: Bool = false) {

        // WARNING: 4 or 5 channels were supported at the time of creation, as the Muse EEG headset features that many channels. Altering the amount of channels will require a redesign of the whole fitting procedure.
        var channels = 4
        auxChannel ? (channels = 5) : ()
        
        // reset source and unregister, only if it differs from before
        if dataSource != nil {
            if dataSource!.type == source && dataSource!.channels.count == channels {
                return
            } else {
                dataSource?.stop()
                dataSource?.dataController = nil
                dataSource = nil
            }
        }
        
        if dataSource == nil {
            // reset states
            for state in DeviceStates.allValues {
                deviceState[state] = false
            }
            
            // set new source
            switch source{
            case .muse:
                dataSource = MuseDelegate.shared
            case .oscillator:
                dataSource = OscillatorDelegate.shared
            }
            
            // set number of channels
            dataSource?.setChannels(count: channels)
            
            // reset publish values
            data.onNext(Array<Double>(repeating: 0.0, count: dataSource!.channels.count))
            timeStamp.onNext(0)
            
            // register self as listener
            dataSource?.dataController = self
        }
    }
    
    func start() {
        guard dataSource != nil else {return}
        
        if !isRunning {
            isRunning = true
            // start source
            dataSource?.start()
        }
    }
    
    func stop() {
        guard dataSource != nil else {return}
        
        if isRunning {
            isRunning = false
            dataSource?.stop()
            dataSource?.dataController = nil
            dataSource = nil
        }
    }
    
    // DataControllerCallBack Methods
    /// Send the new data with a new time stamp
    func dataSource(_ dataSource: DataSource?, didReceiveData data: [Double], withTimeStamp timeStamp: Int) {
        self.data.onNext(data)
        self.timeStamp.onNext(timeStamp)
    }
    
    /// Send an update of the device state as Bool
    func dataSource(_ dataSource: DataSource?, didChangeStateTo state: DeviceStates, toBool bool: Bool = true) {
        
        // in case the state does not exist, create it and set it to false
        if deviceState[state] == nil {
            deviceState[state] = false
        }
        
        // if the device state is false, set it to true and emit information
        if deviceState[state] != bool {
            deviceState[state] = bool
            // Note that only the information is emitted that "something" changed, the actual content is in the dictionary `deviceState` that is attached to this class
            DispatchQueue.main.async {
                self.deviceStateChanged.onNext(true)
                
                // Small hack to let the user know that the headset is connecting
                if state == .found && bool {
                    self.nc.postBanner(message: NSLocalizedString("#foundHeadset#", comment: ""), style: "info", say: true)
                }
            }
        }
    }
}

