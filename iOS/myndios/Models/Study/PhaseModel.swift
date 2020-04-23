//
//  PhaseModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 20.08.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import Foundation
import GameKit

/// available phases. this needs to be extended if a new phase was to be created, or the custom option could be used.
enum Phases: String, Codable {
    case prompt
    case fixation
    case pause
    case custom
}

/**
 Note: Feedback functionality can be controlled with this variable, but it is not implemented in the exsting phases at the time of development.
 */
enum Feedback: String, Codable {
    case wait
    case up
    case down
    case none
}

/**
 Low-level definition. The `PhaseModel` is the smallest unit in a scenario. Prompt, fixation, and pause phases are implemented.  Duration and marker are set in the trial definition. Duration can be set to `0` for prompts, in which case the phase concludes once the prompt was read out to the subject. Pause phases contain a random jitter between -1 and 1 second that is added to the phase duration automatically. Note: Phases also contain a feedback variable, but displaying feedback is not implemented yet.
 */
class PhaseModel: Codable {
    
    let type: Phases
    
    let text: String
    var duration: Double
    let marker: Int
    let feedback: Feedback
    
    init(type: Phases = .custom, text: String, duration: Double, marker: Int, feedback: Feedback = .none) {
        self.type = type
        self.text = text
        self.duration = duration
        self.marker = marker
        self.feedback = feedback
    }
    
    convenience init (type: Phases, duration: Double, marker: Int, feedback: Feedback = .none) {
        switch type {
        case .fixation:
            self.init(type: .fixation, text: "", duration: duration, marker: marker, feedback: feedback)
        case .pause:
            let dist = GKRandomDistribution(lowestValue: -1, highestValue: +1)
            self.init(type: .pause, text: NSLocalizedString("#takeBreak#", comment: ""), duration: duration + Double(dist.nextUniform()), marker: marker, feedback: feedback)
        default:
            fatalError("Convenience init cannot be used on this type of phase")
        }
    }
    
}
