//
//  OscillatorDelegate.swift
//  myndios
//
//  Created by Matthias Hohmann on 19.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import Foundation
import GameKit
import RxSwift

enum OscillatorMode {
    case random
    case sineWave
}

/**
 The `OscillatorDelegate` is a dummy source that creates random oscillations for testing without the need for external hardware. This class can be used as a blueprint for new data sources.
 */
class OscillatorDelegate: NSObject, DataSource {
    
    static let shared = OscillatorDelegate()
    
    // Required by DataSourceDelegate Protocol
    let type: Devices = .oscillator
    var battery: Double = 100.0
    var channels = [String]()
    let samplingRate: Int = 128 // we fix this
    
    weak var dataController: DataControllerCallBack?
    
    var isRunning: Bool = false
    
    // Generate Data - Gaussian Noise
    private let gk = GKRandomSource()
    private var gaussian: GKGaussianDistribution
    private var deviation = 300.00

    // Timing
    private var timer: DispatchSourceTimer?
    private var fittingTimer: Timer?
    private var disposeBag = DisposeBag()
    private var startTime = Date()
    private var isAutoPilotActive: Bool = false
    
    
    private override init() {
        self.gaussian = GKGaussianDistribution(randomSource: gk, mean: 800.0, deviation: Float(deviation))
        super.init()
    }
    
    func setChannels(count: Int) {
        
        // make sure oscillator is not running
        if isRunning {
            stop()
        }
        
        // can support infinite channels
        channels.removeAll()
        for i in 1...count {
            channels.append("Channel\(i)")
        }
    }
    
    // Convenience function to comply with the DataSource Protocol
    func start() {
        if !isRunning {
            isRunning = true
            start(mode: .sineWave)
        }
        print("Started Oscillator Delegate")
    }
    
    func start(mode: OscillatorMode) {
        
        // Set up Data Generator
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.global(qos: .background))
        timer?.schedule(deadline: .now(), repeating: .microseconds((1000/self.samplingRate)*1000), leeway: .nanoseconds(0))
        timer?.setEventHandler(handler: {self.update(mode)})
        timer?.resume()
        
        // Set start time to NOW and start the process
        startTime = Date()
        
        setAutoPilot(true)
        
        dataController?.dataSource(self, didChangeStateTo: .found, toBool: true)
        dataController?.dataSource(self, didChangeStateTo: .connected, toBool: true)
        dataController?.dataSource(self, didChangeStateTo: .onHead, toBool: true)
    }
    
    func update(_ mode: OscillatorMode) {
        DispatchQueue.global(qos: .background).sync {
            var samples = [Double]()
            let n = Double(Date().timeIntervalSince(self.startTime)) // get point in time for sine function
            
            switch mode {
            case .random:
                for _ in 1...self.channels.count {
                    //                samples.append(self.amplitude * Double(sin(2*Double.pi + (self.frequency*Double(ch)) * (t/180))) + self.phase + Double(gaussian.nextUniform()))
                    samples.append(Double(self.gaussian.nextInt()))
                }
            case .sineWave:
                // sine function is f(n) = amplitude * sin(2pi * freq * n)
                // we fix f at 10 * channelnumber
                for i in 1...self.channels.count {
                    samples.append(self.deviation * sin(self.phi(n, 10 * Double(i))))
                }
            }

            self.dataController?.dataSource(self, didReceiveData: samples, withTimeStamp: Int(n))
        }
        
    }
    
    func stop() {
        isRunning = false
        timer?.cancel()
        dataController?.dataSource(self, didChangeStateTo: .disconnected, toBool: true)
    }
    
    /**
     The autopilot simulates an increase and decrease in variance over time. This was needed to test the fitting procedure and it is enabled by default.
     */
    func setAutoPilot(_ active: Bool) {
        isAutoPilotActive = active
        if isAutoPilotActive {
            var descending = false
            fittingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
                if descending {
                    self.changeSignalQuality(to: self.deviation - 10)
                } else {
                    self.changeSignalQuality(to: self.deviation + 3)
                }

                if self.deviation <= 1 {
                    descending = false
                } else if self.deviation >= 100 {
                    descending = true
                }
            })
        } else {
            print("Deactivating Autopilot")
            fittingTimer?.invalidate()
            changeSignalQuality(to: 300)
        }
    }
    
    /// Optionally, the varation of the signal can be set to a specific value with this function
    func changeSignalQuality(to value: Double) {
        self.deviation = value
    }
    
    fileprivate func phi(_ n: Double, _ f: Double) -> Double {
        return(2 * Double.pi * f * n )
    }
}
