//
//  TTSController.swift
//  myndios
//
//  Created by Matthias Hohmann on 19.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import MediaPlayer

protocol TTSListener: class {
    func ttsChanged(toState state: TTSStates, withText text: String)
}
enum TTSStates {
    case started
    case finished
    case canceled
    case paused
}

/**
 The `TTSController` is essentially a wrapper for the iOS text-to-speech functionality. It adds a few functions to track the state of the TTS engine, check the current volume during scenario execution, and allow `ScenarioView` to advance in variable-length prompts after the prompt was said out loud.
 */
class TTSController: NSObject {
    
    static let shared = TTSController()
    weak var listener: TTSListener?
    
    private let defaults = UserDefaults.standard
    private var voice: AVSpeechSynthesisVoice!
    private var synth = AVSpeechSynthesizer()
    private var silentSpeechTimer: Timer?
    
    
    // MARK: - Initialization
    override init() {
        super.init()
        do {
            // declare TTS voice as audio playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
        synth.delegate = self
        
        // load the voice that fits the current locale
        loadHighQualityVoiceIfAny()
        
    }
    
    func checkVolume() -> Float {
        return MPVolumeView.getVolume()
    }
    
    fileprivate func loadHighQualityVoiceIfAny() {
        self.voice = AVSpeechSynthesisVoice()
        
    }
    
    // MARK: - Public functions
    func say(_ text: String, force: Bool = false) {
        if defaults.bool(forKey: "isTTSEnabled") || force {
            sayOutLoud(text)
        } else {
            saySilently(text)
        }
    }
    
    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        listener?.ttsChanged(toState: .canceled, withText: "")
        silentSpeechTimer?.invalidate()
    }
    
    // MARK: - Private functions
    /// this was initially implemented to have phases advance even if TTS is disabled. The TTSController "imagines" saying a prompt and sends a signal once that is completed. In the current implementation, all prompts are read out regardless of the users TTS choice, so this is obsolete.
    fileprivate func saySilently(_ text: String) {

        let time = Double((text.count * 70) / 1000)
        listener?.ttsChanged(toState: .started, withText: text)
        silentSpeechTimer = Timer.scheduledTimer(withTimeInterval: time, repeats: false, block: {[weak self] _ in
            self?.listener?.ttsChanged(toState: .finished, withText: text)})
    }
    
    /// this is the general speak function
    fileprivate func sayOutLoud(_ text: String) {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        synth.speak(utterance)
    }
}

/// this triggers functions based on the state of the TTS engine
extension TTSController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        listener?.ttsChanged(toState: .started, withText: utterance.speechString)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        listener?.ttsChanged(toState: .finished, withText: utterance.speechString)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        listener?.ttsChanged(toState: .canceled, withText: utterance.speechString)
    }
}

/// this was implemented to control the volume of the iOS device and make it loud enough on first launch such that subjects dont accidentially miss the TTS option. was not used as all devices were configured accordingly upfront.
extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            slider?.value = volume;
        }
    }
    
    /// this is used to check if the volume is too low in `ScenarioView` and send a warning, as subjects may not hear prompts in closed-eyes conditions
    static func getVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}
