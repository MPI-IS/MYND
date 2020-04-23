//
//  TrialModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 12.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import Foundation
import GameKit

// available trials. this needs to be extended to include new trial variants, or the "custom" option can be used
enum Trials: String, Codable {
    case welcome
    case goodbye
    case eyesOpen
    case eyesClosed
    case music
    case positiveMemories
    case mentalSubtraction
    case signalUp
    case signalDown
    case smile
    case frown
    case custom
}

/**
 Mid-level definition. The `TrialModel` is a container of several *Phases* that always occur in the same order. For example, the *eyes open* trial consists of 3 phases: 1) the prompt that instructs subjects to relax and keep their eyes open, 2) a 60-second fixation cross, which is the phase where the relevant EEG data is recorded, and 3) a short pause before the next trial is called. Trials take a 3-digit `basemarker` and generate phases with markers in +5 or +10 increments. The relevant marker that indicates the start of a fixation period, e.g., `320` in the eyes-open trial, must be indicated in the `ParadigmModel` such that the analysis program loads to correct phase for analysis later on.
 */
class TrialModel: NSObject, Codable {
    
    let type: Trials
    let marker: Int
    var duration: Double
    
    var phases = [PhaseModel]()
    var phaseIndex: Int = 0
    
    static func make(type: Trials, marker: Int, counting: Int = 1) -> [TrialModel] {
        var trials = [TrialModel]()
        for _ in 1...counting {
            trials.append(TrialModel(type: type, marker: marker))
        }
        return trials
    }
    
    init(type: Trials = .custom, marker: Int = 100, phases: [PhaseModel] = []) {
        self.type = type
        self.marker = marker
        self.phases = phases
        var duration = 0.0
        for phase in phases {
            duration += phase.duration
        }
        self.duration = duration
        super.init()
    }
    

    /// create the trials based on the enum above with the base marker value passed by `ScenarioModel`
    convenience init(type: Trials, marker: Int) {
        var phases = [PhaseModel]()
        switch type {
        case .welcome:
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#sitStill#", comment: ""), duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 5, marker: marker + 10, feedback: .wait))
        case .goodbye:
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#thankYou#", comment: ""), duration: 0, marker: marker + 10))
        case .eyesOpen:
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#eyesOpen#", comment: ""), duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 60, marker: marker + 20, feedback: .down))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30, feedback: .wait))
        case .eyesClosed:
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#eyesClosed#", comment: ""), duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 60, marker: marker + 20, feedback: .up))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30, feedback: .wait))
        case .music:
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#getReady#", comment: ""), duration: 0, marker: marker, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 3, marker: marker + 5, feedback: .wait))
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#musicImagery#", comment: ""), duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20, feedback: .up))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30))
        case .positiveMemories:
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#getReady#", comment: ""), duration: 0, marker: marker, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 3, marker: marker + 5, feedback: .wait))
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#positiveMemory#", comment: ""), duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20, feedback: .wait))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30))
        case .mentalSubtraction:
            var randBig = GKGaussianDistribution(lowestValue: 500, highestValue: 900).nextInt()
            while (randBig % 5 == 0) || (randBig % 10 == 0) {
               randBig = GKGaussianDistribution(lowestValue: 500, highestValue: 900).nextInt()
            }
            var randSmall = GKGaussianDistribution(lowestValue: 3, highestValue: 9).nextInt()
            while (randSmall % 5 == 0) {
                randSmall = GKGaussianDistribution(lowestValue: 3, highestValue: 9).nextInt()
            }
            phases.append(PhaseModel(type: .prompt, text: NSLocalizedString("#getReady#", comment: ""), duration: 0, marker: marker, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 3, marker: marker + 5, feedback: .wait))
            phases.append(PhaseModel(type: .prompt, text: String(format: NSLocalizedString("#mentalSubtraction#", comment: ""), randBig, randSmall), duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20, feedback: .wait))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30))
        case .signalUp:
            phases.append(PhaseModel(type: .prompt, text: "Try to keep up the signal quality", duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20, feedback: .up))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30, feedback: .wait))
        case .signalDown:
            phases.append(PhaseModel(type: .prompt, text: "Bring the signal quality down", duration: 0, marker: marker + 10, feedback: .wait))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20, feedback: .down))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30, feedback: .wait))
        case .smile:
            phases.append(PhaseModel(type: .prompt, text: "Smile", duration: 0, marker: marker + 10))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30))
        case .frown:
            phases.append(PhaseModel(type: .prompt, text: "Frown", duration: 0, marker: marker + 10))
            phases.append(PhaseModel(type: .fixation, duration: 30, marker: marker + 20))
            phases.append(PhaseModel(type: .pause, duration: 5, marker: marker + 30))
        case .custom:
            fatalError("Cannot use convenience initializer with custom trial type")
        }
        self.init(type: type, marker: marker, phases: phases)
    }
    
    /// called by `ScenarioModel` to advance during presentation
    func advancePhase() -> Bool {
        guard phaseIndex + 1 < phases.count else {
            phaseIndex = phases.count
            return false
        }
        phaseIndex += 1
        return true
    }
    
    func resetPhase() {
        phaseIndex = 0
    }
    
    func getPhase() -> (index: Int, object: PhaseModel?) {
        guard phaseIndex < phases.count else {return (index: -1, object: nil)}
        return (index: phaseIndex, object: phases[phaseIndex])
    }
    
}
