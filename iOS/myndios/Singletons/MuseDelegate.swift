//
//  MuseDelegate.swift
//  myndios
//
//  Created by Matthias Hohmann on 21.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import CoreBluetooth

/// # A singleton class to interface with the muse headband
/**
 ## Usage
 Reference with MuseDelegate.singleton from anywhere
 
 ## Members
 - channels [String Array]: Channel names, ordered
 - samplingRate [Int]: Nominal sampling rate
 
 ## Signals
 - deviceInfo(message)[String]: Information concerning the device
 - newDataPackReceived(data)[Double]: Raw data from the headset
 - batteryInfo(battery)[Double]: Remaining battery life
 - artifactDetected(): Built-in Jaw clench and Eyeblink detection
 
 ## Slots
 - start: looks for the first muse headband and starts streaming
 - stop: disconnects the muse headband, if any
 
This swift-class was build in part with the Obj-C example-code for iOS interfacing with the Muse EEG from www.choosemuse.com
Note: The  Obj-C`Muse.framwork`is linked via bridging-header to this class, IXNMuseConnectionListener, IXNMuseDataListener, IXNMuseListener are used.
*/
class MuseDelegate: NSObject, DataSource, IXNMuseConnectionListener, IXNMuseDataListener, IXNMuseListener {
    
    static let shared = MuseDelegate()
    
    // Required by DataSourceDelegate Protocol
    let type: Devices = .muse
    var battery: Double = 100.0
    var channels = [String]()
    let samplingRate: Int = 256
    
    weak var dataController: DataControllerCallBack?
    
    // Internal Variables
    private var manager: IXNMuseManagerIos?
    private var muse: IXNMuse?
    private var preset: IXNMusePreset?

    private var executionTimer: DispatchSourceTimer?
    private var executeCommand: DispatchWorkItem! = nil
    private var state: DeviceStates = .unknown
    private var isRunning: Bool = false
    
    private override init() {
        super.init()
        
        // initialize delegates
        manager = IXNMuseManagerIos.sharedManager()
        manager?.museListener = self
        executeCommand = DispatchWorkItem  {
            self.muse?.execute()
        }
        setChannels(count: 4)
    }
    
    func setChannels(count: Int) {
        
        // make sure that there is no muse attached
        if muse != nil {
            stop()
            disconnect()
        }
        
        if count <= 4 {
           channels = ["Left Ear", "Left Front", "Right Front", "Right Ear"]
            preset = IXNMusePreset.preset21
        } else if count == 5 {
            channels = ["Left Ear", "Left Front", "Right Front", "Right Ear", "AUX"]
            preset = IXNMusePreset.preset20
        } else {
            print("Cannot support more channels than 5")
            return
        }
    }
    
    /**
     - If no Muse is connected, the manager starts the listening process
     - If a Muse is already connected, nothing happens and a message will be emitted
     */
    func start() {
        print("Started Muse Delegate")
        if isRunning {return}
        
        isRunning = true
        manager?.startListening()
    }
    
    /// Disconnect muse and set bool to false
    func stop() {
        print("Stopped Muse Delegate")
        if !isRunning {return}
        
        isRunning = false
        manager?.stopListening()
        muse?.disconnect()
    }
    
    func disconnect() {
        isRunning = false
        
        executionTimer?.cancel()
        muse?.unregisterAllListeners()
        muse = nil
    }
    
    /// Receive Connection Info
    func receive(_ packet: IXNMuseConnectionPacket, muse: IXNMuse?) {
        switch packet.currentConnectionState {
        case .disconnected:
            // when the device disconnected itself, clean up afterwards
            dataController?.dataSource(self, didChangeStateTo: .disconnected, toBool: true)
            disconnect()
        case .connected:
            dataController?.dataSource(self, didChangeStateTo: .connected, toBool: true)
        case .connecting:
            dataController?.dataSource(self, didChangeStateTo: .found, toBool: true)
        default:
            break
        }
    }
    
    // Rceceive Data Packages
    func receive(_ packet: IXNMuseDataPacket?, muse: IXNMuse?) {
        
        // make sure the packet can be unwrapped, else return
        guard let packet = packet else {
            return
        }

        switch packet.packetType() {
        case .eeg:
            let eeg = packet.values().filter({$0 != NSDecimalNumber.notANumber}) as! [Double]
            let timeStamp = Int(packet.timestamp())
            dataController?.dataSource(self, didReceiveData: eeg, withTimeStamp: timeStamp)
        case .battery:
            battery = packet.values().first! as! Double
            if battery < 20 {
                dataController?.dataSource(self, didChangeStateTo: .batteryLow, toBool: true)
            }
        default:
            break
        }
    }
    
    /// Receive On Head Information
    func receive(_ packet: IXNMuseArtifactPacket, muse: IXNMuse?) {
        if packet.headbandOn {
            dataController?.dataSource(self, didChangeStateTo: .onHead, toBool: true)
            // Deregister the artifact listener when device is on head
            self.muse?.unregisterDataListener(self, type: IXNMuseDataPacketType.artifacts)
        }
    }
    
    // Internal function: Use first Muse you encounter
    func museListChanged() {
        guard let muse = manager?.getMuses().first else {
            print("Couldnt establish connection, continue searching")
            return
        }
       
        self.muse = muse
        manager?.stopListening()
        connect()
    }
    
    /// Internal function: Connect to the headset
    func connect() {

        guard preset != nil && muse != nil else {
            print("preset or muse were nil")
            return
        }
        
        muse?.setPreset(preset!)
        muse?.register(self)
        muse?.register(self, type: IXNMuseDataPacketType.artifacts)
        muse?.register(self, type: IXNMuseDataPacketType.battery)
        muse?.register(self, type: IXNMuseDataPacketType.eeg)
        muse?.connect()
        
        executionTimer?.cancel()
        executionTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        executionTimer?.schedule(deadline: .now(), repeating: .milliseconds(60), leeway: .milliseconds(10))
        executionTimer?.setEventHandler(handler: executeCommand)
        executionTimer?.resume()
    }
}
