/// DSBuffer
///
/// Created by Yang Liu (gloolar [at] gmail [dot] com) on 16/6/20.
/// Copyright © 2016年 Yang Liu. All rights reserved.


import Foundation

/// Fixed-length buffer for windowed signal processing
public class DSBuffer {
    
    private var buffer: OpaquePointer
    private var size: Int
    
    private var fftIsSupported: Bool
    private var fftData: [dsbuffer_complex]?
    private var fftIsUpdated: Bool?
    
    // MARK: Initializer and deinitializer
    
    /// Initializer
    ///
    /// - parameter size: Buffer length. If you set fftIsSupperted to be true, the size should be **even** number
    /// - parameter fftIsSupported: Whether FFT will be performed on the buffer
    /// - returns: DSBuffer object
    ///
    /// *Tips*:
    ///
    /// - If you do not need to perform FFT on the buffer, set fftIsSupperted to be false could save 50% memory.
    /// - If you need to perform FFT, set buffer size to power of 2 could accelerate more.
    public init(_ size: Int, fftIsSupported: Bool = true) {
        if (fftIsSupported && size % 2 == 1) {
            print(String(format: "WARNING: size must be even for FFT. Reset size to: %d.", size+1))
            self.size = size + 1
        }
        else {
            self.size = size
        }
        self.buffer = dsbuffer_new(size, fftIsSupported)
        
        self.fftIsSupported = fftIsSupported
        if (fftIsSupported) {
            self.fftData = [dsbuffer_complex](repeating: dsbuffer_complex(real: 0.0, imag: 0.0), count: self.size/2+1)
            self.fftIsUpdated = false
        }
    }
    
    
    /// :nodoc: deinitializer
    deinit {
        dsbuffer_free_unsafe(self.buffer)
    }
    
    // MARK: Regular operations
    
    /// Push new value to buffer (and the foremost will be dropped)
    ///
    /// - parameter value: New value to be added
    public func push(_ value: Float) {
        dsbuffer_push(self.buffer, value)
        if (self.fftIsSupported) {
            self.fftIsUpdated = false
        }
    }
    
    /// Get data by index
    public func dataAt(_ index: Int) -> Float {
        return dsbuffer_at(self.buffer, index)
    }
    
    /// Get Buffer size
    public var bufferSize: Int {
        return self.size
    }
    
    
    /// Dump buffer as array
    public var data: [Float] {
        var dumped = [Float](repeating: 0.0, count: self.size)
        dsbuffer_dump(self.buffer, &dumped)
        return dumped
    }
    
    
    /// Reset buffer to be zero filled
    public func clear() {
        dsbuffer_clear(self.buffer)
        if (self.fftIsSupported) {
            self.fftIsUpdated = false
        }
    }
    
    
    /// Print buffer
    public func printBuffer(_ dataFormat: String) {
        print("DSBuffer size: \(self.size)")
        for idx in 0..<self.size {
            print(String(format: dataFormat, dsbuffer_at(self.buffer, idx)), terminator: " ")
        }
        print("\n")
    }
    
    
    // MARK: Vector-like operations
    
    /// Add value to each buffer data
    public func add(_ withValue: Float) -> [Float] {
        var result = [Float](repeating: 0.0, count: self.size)
        dsbuffer_add(self.buffer, withValue, &result)
        return result
    }
    
    
    /// Multiply each buffer data with value
    public func multiply(_ withValue: Float) -> [Float] {
        var result = [Float](repeating: 0.0, count: self.size)
        dsbuffer_multiply(self.buffer, withValue, &result)
        return result
    }
    
    
    /// Modulus by value of each buffer data
    public func mod(_ withValue: Float) -> [Float] {
        var result = [Float](repeating: 0.0, count: self.size)
        dsbuffer_mod(self.buffer, withValue, &result)
        return result
    }
    
    
    /// Remove mean value
    public var centralized: [Float] {
        var result = [Float](repeating: 0.0, count: self.size)
        dsbuffer_remove_mean(self.buffer, &result)
        return result
    }
    
    
    /// Normalize vector to have unit length
    ///
    /// - parameter centralized: Should remove mean?
    public func normalizedToUnitLength(_ centralized: Bool) -> [Float] {
        var result = [Float](repeating: 0.0, count: self.size)
        dsbuffer_normalize_to_unit_length(self.buffer, centralized, &result)
        return result
    }
    
    
    /// Normalize vector to have unit variance
    ///
    /// - parameter centralized: Should remove mean?
    public func normalizedToUnitVariance(_ centralized: Bool) -> [Float] {
        var result = [Float](repeating: 0.0, count: self.size)
        dsbuffer_normalize_to_unit_variance(self.buffer, centralized, &result)
        return result
    }
    
    
    /// Perform dot production with array
    public func dotProduct(_ with: [Float]) -> Float {
        assert(self.size == with.count)
        return dsbuffer_dot_product(self.buffer, with)
    }
    
    
    // MARK: Time-domain features
    
    /// Mean value
    public var mean: Float {
        return dsbuffer_mean(self.buffer)
    }
    
    
    /// Mean value
    public var sum: Float {
        return dsbuffer_sum(self.buffer)
    }
    
    
    /// Vector length
    public var length: Float {
        return dsbuffer_length(self.buffer)
    }
    
    
    /// Square of length
    public var energy: Float {
        return dsbuffer_energy(self.buffer)
    }
    
    
    /// Max value
    public var max: Float {
        return dsbuffer_max(self.buffer)
    }
    
    
    /// Min value
    public var min: Float {
        return dsbuffer_min(self.buffer)
    }
    
    
    /// Variance
    public var variance: Float {
        return dsbuffer_variance(self.buffer)
    }
    
    
    /// Standard deviation
    public var std: Float {
        return dsbuffer_std(self.buffer)
    }
    
    
    // MARK: FFT & frequency-domain features
    
    // Perform FFT if it is not updated
    private func updateFFT() {
        assert (self.fftIsSupported)
        if (!self.fftIsUpdated!) {
            _ = fft()
        }
    }
    
    
    /// Perform FFT
    ///
    /// **Note for FFT related methods**:
    ///
    /// - Set fftIsSupported to true when creating the buffer.
    /// - Buffer size should be even. If you pass odd size when creating the buffer, it is automatically increased by 1.
    /// - Only results in nfft/2+1 complex frequency bins from DC to Nyquist are returned.
    public func fft() -> (real: [Float], imaginary: [Float]) {
        assert (self.fftIsSupported, "FFT is not supported on this buffer")
        dsbuffer_fftr(self.buffer, &self.fftData!)
        self.fftIsUpdated = true
        return (self.fftData!.map{$0.real}, self.fftData!.map{$0.imag})
    }
    
    
    /// FFT sample frequencies
    ///
    /// - returns: array of size nfft/2+1
    public func fftFrequencies(_ fs: Float) -> [Float] {
        assert (self.fftIsSupported)
        var fftFreq = [Float](repeating: 0.0, count: self.size/2+1)
        dsbuffer_fft_freq(self.buffer, fs, &fftFreq)
        return fftFreq
    }
    
    
    /// FFT magnitudes, i.e. abs(fft())
    ///
    /// - returns: array of size nfft/2+1
    public func fftMagnitudes() -> [Float] {
        updateFFT()
        return self.fftData!.map{sqrt($0.real*$0.real + $0.imag*$0.imag)}
    }
    
    
    /// Square of FFT magnitudes, i.e. (abs(fft()))^2
    ///
    /// - returns: array of size nfft/2+1
    public func squaredPowerSpectrum() -> [Float] {
        updateFFT()
        var sps = self.fftData!.map{($0.real*$0.real + $0.imag*$0.imag) * 2}
        sps[0] /= 2.0 // DC
        return sps
    }
    
    
    /// Mean-squared power spectrum, i.e. (abs(fft()))^2 / N
    ///
    /// - returns: array of size nfft/2+1
    public func meanSquaredPowerSpectrum() -> [Float] {
        updateFFT()
        var pxx = self.fftData!.map{($0.real*$0.real + $0.imag*$0.imag) * 2 / Float(self.size)}
        pxx[0] /= 2.0 // DC
        return pxx
    }
    
    
    /// Power spectral density (PSD), i.e. (abs(fft()))^2 / (fs*N)
    ///
    /// - returns: array of size nfft/2+1
    public func powerSpectralDensity(_ fs: Float) -> [Float] {
        updateFFT()
        var psd = self.fftData!.map{($0.real*$0.real + $0.imag*$0.imag) * 2.0 / (fs * Float(self.size))}
        psd[0] /= 2.0 // DC
        return psd
    }
    
    
    /// Average power over specific frequency band, i.e. mean(abs(fft(from...to))^2)
    public func averageBandPower(_ fromFreq: Float = 0, toFreq: Float, relative: Bool = false, fs: Float) -> Float {
        assert (fromFreq >= 0)
        assert (toFreq <= fs/2.0)
        assert (fromFreq <= toFreq)
        
        updateFFT()
        
        // Compute index range corresponding to given frequency band
        // f = idx*df = idx*fs/N ==> idx = N*f/fs
        let fromIdx = Int(floor(fromFreq * Float(self.size) / fs))
        let toIdx = Int(ceil(toFreq * Float(self.size) / fs))
        
        let bandPower = self.fftData![fromIdx...toIdx].map{log($0.real*$0.real+$0.imag*$0.imag)}
        
        // Averaging
        if relative {
            let s = averageBandPower(toFreq: fs/2.0, fs: fs)
            return (bandPower.reduce(0.0, +) / Float(toIdx - fromIdx + 1)) / s
        }
        else {
            return bandPower.reduce(0.0, +) / Float(toIdx - fromIdx + 1)
        }
    }
    
    public func bandPower(_ fromFreq: Float = 0, toFreq: Float, step: Float = 1, fs: Float) -> [Float] {
        assert (fromFreq >= 0)
        assert (toFreq <= fs/2.0)
        assert (fromFreq <= toFreq)
        
        updateFFT()
        
        // Compute index range corresponding to given frequency band
        // f = idx*df = idx*fs/N ==> idx = N*f/fs
        var bp = [Float]()
        
        for i in stride(from: fromFreq, to: toFreq - step, by: step) {
            let fromIdx = Int(floor(i * Float(self.size) / fs))
            let toIdx = Int(ceil((i+step) * Float(self.size) / fs))
            let size = Float(toIdx - fromIdx + 1)
            let fbp = self.fftData![fromIdx...toIdx].map{log($0.real*$0.real+$0.imag*$0.imag)}
            
            bp.append(fbp.reduce(0.0, +) / size)
        }
        
        // NO Averaging
        return bp
    }
    
    
    // MARK: FIR filter
    
    // Setup FIR filter
    public func setupFIRFilter(_ FIRTaps: [Float]) {
        assert (self.size >= FIRTaps.count)
        dsbuffer_setup_fir(self.buffer, FIRTaps, FIRTaps.count)
    }
    
    
    /// Get latest FIR output
    public func latestFIROutput() -> Float {
        return dsbuffer_latest_fir_output(self.buffer)
    }
    
    
    /// FIR filtered buffer
    public func FIRFiltered() -> [Float] {
        var output = [Float](repeating: 0.0, count: self.size)
        dsbuffer_fir_filter(self.buffer, &output)
        return output
    }
    
    
    /// :nodoc: Self test
    public class func test() {
        print("\nDSBuffer test: ==============\n")
        
        let size = 16
        let buf = DSBuffer(size, fftIsSupported: true)
        buf.printBuffer("%.2f")
        
        let signalData: [Float] = [1.0, 4, 2, 5, 6, 7, -1, -8]
        for value in signalData {
            buf.push(value)
            //            print(buf.signals)
        }
        buf.printBuffer("%.2f")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let fft = buf.fft()
        let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
        print("FFT time: \(deltaTime)")
        print(fft)
        
        let fftSM = buf.squaredPowerSpectrum()
        print(fftSM)
        
        
        buf.clear()
        for _ in 0 ..< 10000 {
            let a = Float(arc4random_uniform(100))
            buf.push(a)
            let signals = buf.data
            //            print(a)
            //            print(signals)
            assert(signals[size-1] == a)
        }
        
        
        let norm = buf.normalizedToUnitLength(true)
        let coeff = vDotProduct(norm, v2: norm)
        print(String(format: "coeff: %.2f\n", coeff))
        
        
        print("\nDSBuffer test OK.\n\n")
    }
    
}
