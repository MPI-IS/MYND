//
//  ProcessingDelegate.swift
//  myndios
//
//  Created by Matthias Hohmann on 20.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import RxSwift
import Foundation
import Surge
import Accelerate

// this is a modified fork from https://herrkaefer.com/AccelerateWatch/ (MIT licensed). It contains functions for ring-buffering and bandpower computations
import AccelerateWatch

/**
 - in `signalQuality` mode, signal quality is defined by the variance of a moving, weighted average of the raw signal. Please refer to the references on the main page for an in-depth discussion of this method.
 - in `noiseDetection` mode, signal quality is defined by the amount of 50Hz noise in the raw signal. This is used to help subjects find a location with little electromagnetic interference. This mode also computes the full real-time EEG band-power spectrum that is emitted through `bp`. It is only accessible in developer-mode raw data display during hardware preparation. This computation is handled by the `FFTDelegate`.
 */
enum ProcessingMode: String {
    case signalQuality, noiseDetection
}

/**
 The `ProcessingDelegate` is instantiated during EEG recording. It observes the `data` signal from the `DataController`, and emits `avgSignalQuality` and band-power `bp`.
 */
class ProcessingDelegate: NSObject {
    
    /// dedicated background queue for processing so main thread is not blocked
    let processingQueue = DispatchQueue.global(qos: .background)
    
    /// WEAK dependency on data controller
    weak var dataController: DataController?
    
    // MARK: - Subscribables
    var signalQuality = BehaviorSubject<[Double]>(value: [100]) // channels, buffered
    var avgSignalQuality = BehaviorSubject<[Double]>(value: [100]) // channels
    var bp = BehaviorSubject<[Float]>(value: [100]) // channels
    var isRunning: Bool = false
    
    // MARK: - Parameters
    var varianceThreshold = 150.00 // in muVsquared
    
    // MARK: - Internal
    private var disposeBag = DisposeBag()
    private var channelCount: Int = 0 // channels
    var winStep: Double = 0.5
    private var samplingRate: Int = 0
    private var signalQualityWinLength: Int = 5
    private var weights = (old: [Double](), new: [Double]())
    private var mode: ProcessingMode = .signalQuality
    
    // Bandpower specific
    private var buffer = Array<DSBuffer>()
    private var fftTimer: Timer?
    private var fftDelegate: FFTDelegate?
    private var secondsFFTWindow: Float = 4.0
    var spectrum = [[Float]]()
    
    
    // MARK: - Initializer
    /// Init with data controller, make sure sampling rate and channels exist
    init(_ dataController: DataController) {
        super.init()
        commonInit(dataController)
    }
    
    private func commonInit(_ dataController: DataController) {
        // make sure we are not processing anything
        isRunning ? (stop()) : ()
        self.dataController = dataController
        
        guard let samplingRate = dataController.samplingRate,
            let channelCount = dataController.channels?.count else {print("[processingDelegate] dataController was not initialized!"); return}
        
        preallocHelper(samplingRate: samplingRate, channelCount: channelCount)
    }
    
    /// make sure we are not processing when deinitializing due to unowned self in closure
    deinit {
        stop()
    }
    
    
    // MARK: - Control
    func start(mode: ProcessingMode = .signalQuality) {
       
        // make sure a data controller object was set before starting, else do nothing
        guard let dc = dataController else {return}
        
        // if the mode was changed, stop and flush existing progress
        if mode != self.mode {
            stop()
            commonInit(dc)
            self.mode = mode
        }
        
        // if the process is already running, just do nothing
        guard !isRunning else {return}
        
        switch self.mode {
        case .signalQuality:
            startSignalQuality()
        case .noiseDetection:
            startNoiseDetection()
        }
        
    }
    
    private func startSignalQuality() {
        
        // if something changed in the dataController configuration while this object exists, preallocate again
        if dataController!.channels?.count != channelCount || dataController!.samplingRate != samplingRate {
            commonInit(dataController!)
        }
        
        isRunning = true
        let s = ConcurrentDispatchQueueScheduler.init(queue: processingQueue)
        
        // subscribe to the raw data, all with unowned self
        dataController!.data
            .scan([]) {[unowned self] last, new in return self.addToBlock(last, new)}
            .buffer(timeSpan: winStep*1000, count: samplingRate/2, scheduler: s)
            .subscribe({[unowned self] block in self.computeSignalQuality(block.element!)})
            .disposed(by: disposeBag)
        
        // subscribe to self signal quality output
        signalQuality.scan([]) {[unowned self] last, new in self.computeAvgSignalQuality(last, new, self.signalQualityWinLength)}
            .subscribe({[unowned self] sq in DispatchQueue.main.async{self.avgSignalQuality.onNext(sq.element!)}})
            .disposed(by: self.disposeBag)
    }
    
    private func startNoiseDetection() {
        
        fftDelegate = FFTDelegate()
        fftDelegate?.initFFT(length: Float(samplingRate * Int(secondsFFTWindow)), fs: Float(samplingRate))
        
        // Timer for Processing
        fftTimer?.invalidate()
        fftTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: {[weak self] _ in self?.updateFFT()})
        
        // Store incoming data in buffer
        dataController!.data
            .subscribe({[unowned self] block in
                for (c,n) in block.element!.enumerated() {
                    self.buffer[c].push(Float(n))
                }
            }).disposed(by: disposeBag)
    }
    
    // MARK: - Noise Detection Functions
    
    
    private func updateFFT() {
        var sq = [Double]()
        var a = [Float]()
        for (c,n) in buffer.enumerated() {
            let result = fftDelegate!.bandpower(data: n.data)
            spectrum[c] = result.spectrum
            let sqNoise = Double((-1 * result.noise) * 50) + 50
            if sqNoise > 100 {
                sq.append(100)
            } else if sqNoise < 0 {
               sq.append(0)
            } else {
                sq.append(sqNoise)
            }
            a.append(result.bp)
        }
        avgSignalQuality.onNext(sq)
        bp.onNext(a)
    }
    
    func stop() {
        isRunning = false
        disposeBag = DisposeBag()
        fftTimer?.invalidate()
    }
    
    // MARK: - Signal Quality Functions
    
    private func addToBlock(_ last: [Double], _ new: [Double]) -> [Double] {
        guard last.count == new.count else {
            return new
        }
        return zip(last, weights.old).map(*) .+ zip(new, weights.new).map(*)
    }
    
    private func computeSignalQuality(_ block: [[Double]]) {
        processingQueue.sync {
            // Transpose block, now channels x values
            signalQuality.onNext(Surge.transpose(Matrix<Double>(block)).map(computeChannelSignalQuality))
        }
    }
    
    private func computeAvgSignalQuality(_ last: [Double], _ new: [Double], _ winLength: Int) -> [Double] {
        guard last.count == new.count else {
            return new
        }
        
        let avgSq = (last.map{$0*Double(winLength-1)} .+ new)/Double(winLength)
        
        // updateWeights
        do {
        weights.new = try avgSignalQuality.value().map {$0/100}
        weights.old = weights.new.map {1-$0}
        } catch {
        }
        
        return avgSq
    }
    
    private func computeChannelSignalQuality(_ x: ArraySlice<Double>) -> Double {
        let v = pow(Surge.std(x),2)
        guard v > 0 else {return 0}
        if v < varianceThreshold {
            return 110
        } else {
           return(varianceThreshold/v)*100
        }
    }
    
    // MARK: - General Functions
    
    private func preallocHelper(samplingRate: Int, channelCount: Int) {
        self.channelCount = channelCount
        self.samplingRate = samplingRate
        signalQuality.onNext(Array(repeating: 50.0, count: channelCount))
        avgSignalQuality.onNext(Array(repeating: 50.0, count: channelCount))
        bp.onNext(Array(repeating: 0.0, count: channelCount))
        weights = (old: Array(repeating: 0.5, count: channelCount), new: Array(repeating: 0.5, count: channelCount))
        
        // Flush the buffer before resetting
        if !buffer.isEmpty {
            buffer.forEach {$0.clear()}
        }
        
        buffer.removeAll()
        for _ in 1...channelCount {
            buffer.append(DSBuffer(samplingRate * Int(secondsFFTWindow), fftIsSupported: false))
        }
        
        spectrum = Array<Array<Float>>(repeating: [0], count: channelCount)
    }
    
}
