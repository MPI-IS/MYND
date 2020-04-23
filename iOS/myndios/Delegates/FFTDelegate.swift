//
//  FFTDelegate.swift
//  myndios
//
//  Created by Matthias Hohmann on 15.01.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Accelerate
import Surge

/// the FFTDelegate implements a basic bandpower computation.
class FFTDelegate: NSObject {
    
    // FFT
    private var fftWeights: FFTSetupD! = nil
    private var dataLengthLog2: UInt = 0
    private var dataLength: Float = 0.0
    private var mean: Float = 0.0
    private var hann = [Float]()
    private var fx = [Float]()
    private var fs: Float = 0.0
    private var defaultRange = [Float]()
    
    
    func initFFT(length: Float, fs: Float) {
        
        // create setup based on data length
        dataLengthLog2 = vDSP_Length(floor(log2(length)))
        dataLength = length
        self.fs = fs
        
        // create hann window
        let n = Array(0...Int(dataLength) - 1).map {Float($0)}
        hann = n.map {0.5 * (1 - cos((2 * Float.pi * $0) / Float(dataLength - 1)))}
        
        // create actual frequency array
        // Map bins onto actual frequencies with the sampling rate
        // actual frequency bins we have divide count by count * fs to get the full fx vector
        fx = Array(0...Int(dataLength) - 1).map { Float($0) / dataLength * fs}
        
        // generate the default range for the bandpower computation
        for i in stride(from: 0, to: 60, by: 1) {
            defaultRange.append(Float(i))
        }
    }
    
    func bandpower(data: [Float], range: [Float]? = nil) -> (spectrum: [Float], bp: Float, noise: Float) {
        
        // if a specific range was given, use it, else use the default
        var currentRange = [Float]()
        if range != nil {
            currentRange = range!
        } else {
            currentRange = defaultRange
        }

        mean = Surge.mean(data)
        var real = [Float]((data .- Array<Float>(repeating: mean, count: data.count)) .* hann)

        var imaginary = [Float](repeating: 0.0, count: data.count)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary)


        // Debug
        let weights = vDSP_create_fftsetup(dataLengthLog2, FFTRadix(kFFTRadix2))

        withUnsafeMutablePointer(to: &splitComplex) { splitComplex in
            vDSP_fft_zip(weights!, splitComplex, 1, dataLengthLog2, FFTDirection(FFT_FORWARD))
        }

        var magnitudes = [Float](repeating: 0.0, count: data.count)
        withUnsafePointer(to: &splitComplex) { splitComplex in
            magnitudes.withUnsafeMutableBufferPointer { magnitudes in
                vDSP_zvmags(splitComplex, 1, magnitudes.baseAddress!, 1, vDSP_Length(data.count))
            }
        }

        var normalizedMagnitudes = [Float](repeating: 0.0, count: data.count)
        normalizedMagnitudes.withUnsafeMutableBufferPointer { normalizedMagnitudes in
            vDSP_vsmul(sqrt(magnitudes), 1, [2.0 / dataLength], normalizedMagnitudes.baseAddress!, 1, vDSP_Length(data.count))
        }

        vDSP_destroy_fftsetup(weights)
        
        // get rid of zeros as they are undefined for the log
        normalizedMagnitudes = normalizedMagnitudes.map {
            if $0 == 0 {
                return 1
            }
            return $0
        }

        //
        // EEG Treatment
        //
        
        //normalizedMagnitudes = normalizedMagnitudes.map {$0 == 0 ? (return 1) : (return $0)}
        let xf = log(normalizedMagnitudes) // take natural logarithm of result, two sided spectrum
        
        // We now take the frequency indices from this vector
        var X = [Float]()
        for freq in currentRange {
            
            let fromIdx = Int(floor(freq * dataLength / fs))
            let toIdx = Int(ceil((freq+1) * dataLength / fs))
            X.append(Surge.mean(Array(xf[fromIdx...toIdx])))
        }
        
        // this is currently hard-coded to alpha, but can be anything
        let bp = Surge.mean(Array(xf[Int(floor(8 * dataLength / fs))...Int(ceil(12 * dataLength / fs))]))
        
        // this is currently set to 50Hz but can be anything
        let noise = Surge.mean(Array(xf[Int(floor(49 * dataLength / fs))...Int(ceil(51 * dataLength / fs))]))
        
        //return xf
        return (spectrum: X, bp: bp, noise: noise)
    }
    
}
