//
//  ScenarioModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 12.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import ResearchKit

/// Available scenario types
enum ScenarioType: String, Codable {
    case questionnaire
    case recording
}


// Available scenarios. This enum needs to be extended before a new scenario can be added.
enum Scenario: String, Codable {
    // questionnaire types
    case initial
    case motivation
    
    // recording types
    case rest
    case music
    case memories
}

/**The `ScenarioModel` is a representation of either EEG *recording* or *questionnaire* tasks. The model contains static function to generate recording and questionnaire scenarios. It also contains functions to advance through individual trials during a recording, reset progress within a scenario, and get the remaining time. The `Scenario` enumerator contains all currently featured scenarios. */
class ScenarioModel: NSObject {
    
    /**
     The `ScenarioModel`creates a scenario by appending individual *trials* to a *block*. Several blocks make up one scenario. The model also adds meta-data, e.g., after how many trials a block is completed, description, images, baselines, and markers. Note: Blocks were introduced to ensure that subjects completed an equal amount of trials in condition A and B before taking a break and checking the signal quality. The parameter `checkAtIndex` controls the break-point and should be set such that it occurs exactly after a block concluded: e.g., if one block contains 1x welcome, 1x eyes open, 1x eyes closed, and 1x goodbye trials, it should be set to 4.
     */
    
    static func makeRecordingScenario(_ scenario: Scenario, forDay day: Int, atIndex index: Int) -> ScenarioModel {
        var sm: ScenarioModel! = nil
        var trials = [TrialModel]()
        switch scenario {
        case .rest:
            sm = ScenarioModel(day: day,
                               index: index,
                               type: .recording,
                               scenario: scenario,
                               title: NSLocalizedString("#restingState_Title#", comment: ""),
                               text: NSLocalizedString("#restingState_Description#", comment: ""),
                               image: #imageLiteral(resourceName: "resting.jpg"),
                               duration: 15,
                               // this means that a pause will be initiated after 4 trials in `ScenarioView`. This must always correspond to the amount of trials in a block below, such that welcome and goodbye messages are played at the correct point and each block has an equal numer of Class A and B trials
                               checkAtIndex: 4,
                               paradigm: ParadigmModel(title: scenario.rawValue, conditionLabels: ["EyesOpen", "EyesClosed"], conditionMarkers: [320, 420], baseMarkers: [310, 410], baseTime: -3, trialTime: 60),
                               shuffle: true,
                               feedback: false,
                               auxChannel: false)
            
            // Blocks were introduced in this factory to ensure an equal amount of Class A and B trials, but at the same time break up scenarios into smaller chunks and give the subjects a chance to rest and check the fitting quality. The scenario object will only contain an array of trials, and an amount of trials after which to initiate a pause. "Block" is never present as a variable beyond this.
            for _ in 0...2 {
                var block = [TrialModel]()
                block += TrialModel.make(type: .eyesOpen, marker: 300, counting: 1)
                block += TrialModel.make(type: .eyesClosed, marker: 400, counting: 1)
                block.shuffle()
                // set a welcome message and a goodbye message at the beginning and the end of this block
                block.insert(TrialModel(type: .welcome, marker: 900), at: 0)
                block.insert(TrialModel(type: .goodbye, marker: 900), at: block.endIndex)
                trials += block
            }
        case .music:
            sm = ScenarioModel(day: day,
                               index: index,
                               type: .recording,
                               scenario: scenario,
                               title: NSLocalizedString("#musicImagery_Title#", comment: ""),
                               text: NSLocalizedString("#musicImagery_Description#", comment: ""),
                               image: #imageLiteral(resourceName: "music.jpg"),
                               duration: 15,
                               checkAtIndex: 8,
                               paradigm: ParadigmModel(title: scenario.rawValue, conditionLabels: ["MusicImagery", "Counting"], conditionMarkers: [320, 420], baseMarkers: [310, 410], baseTime: -3, trialTime: 30),
                               shuffle: true,
                               feedback: false,
                               auxChannel: false)
            for _ in 0...2 {
                var block = [TrialModel]()
                block += TrialModel.make(type: .music , marker: 300, counting: 3)
                block += TrialModel.make(type: .mentalSubtraction, marker: 400, counting: 3)
                block.shuffle()
                block.insert(TrialModel(type: .welcome, marker: 900), at: 0)
                block.insert(TrialModel(type: .goodbye, marker: 900), at: block.endIndex)
                trials += block
            }
        case .memories:
            sm = ScenarioModel(day: day,
                               index: index,
                               type: .recording,
                               scenario: scenario,
                               title: NSLocalizedString("#positiveMemories_Title#", comment: ""),
                               text: NSLocalizedString("#positiveMemories_Description#", comment: ""),
                               image: UIImage(named: "memories.jpg"),
                               duration: 15,
                               checkAtIndex: 8,
                               paradigm: ParadigmModel(title: scenario.rawValue, conditionLabels: ["Memories", "Counting"], conditionMarkers: [320, 420], baseMarkers: [310, 410], baseTime: -3, trialTime: 30),
                               shuffle: true,
                               feedback: false,
                               auxChannel: false)
            for _ in 0...2 {
                var block = [TrialModel]()
                block += TrialModel.make(type: .positiveMemories, marker: 300, counting: 3)
                block += TrialModel.make(type: .mentalSubtraction, marker: 400, counting: 3)
                block.shuffle()
                block.insert(TrialModel(type: .welcome, marker: 900), at: 0)
                block.insert(TrialModel(type: .goodbye, marker: 900), at: block.endIndex)
                trials += block
            }
        default:
            break
        }
        sm.trials = trials
        sm.totalTrials = trials.count
        return sm
    }
    
    static func makeQuestionnaireScenario(_ scenario: Scenario, forDay day: Int, atIndex index: Int) -> ScenarioModel {
        var sm: ScenarioModel! = nil
        let q = DocumentController.shared.loadQuestionnaire(forScenarioType: scenario)
        sm = ScenarioModel(day: day,
                           index: index,
                           type: .questionnaire,
                           scenario: scenario,
                           title: q.title,
                           text: q.text,
                           image: UIImage(named: q.imageNamed),
                           questions: q.steps)
        return sm
    }
    
    // indicate on which day this scenario should happen, and when on that day
    let day: Int
    let index: Int
    
    // enum descriptors
    let type: ScenarioType
    let scenario: Scenario
    
    // visuals (localized)
    let title: String
    let text: String
    var image: UIImage?
    
    // further information
    var duration: Int?
    var checkAtIndex: Int?
    var paradigm: ParadigmModel?
    
    // playback options
    var shuffle: Bool?
    var feedback: Bool?
    var auxChannel: Bool?
    
    // content
    var trials: [TrialModel]?
    var questions: [ORKStep]?
    
    // user variables
    var scenarioCompleted: Bool = false
    var trialsCompleted: Int = 0
    var totalTrials: Int = 0
    
    init(day: Int, index: Int, type: ScenarioType, scenario: Scenario, title: String, text: String, image: UIImage? = nil,
         duration: Int? = nil, checkAtIndex: Int? = nil, paradigm: ParadigmModel? = nil, shuffle: Bool? = nil,
         feedback: Bool? = nil, auxChannel: Bool? = nil, trials: [TrialModel]? = nil, questions: [ORKStep]? = nil)
    {
        
        self.day = day
        self.index = index
        
        // visuals (localized)
        self.type = type
        self.scenario = scenario
        self.title = title
        self.text = text
        self.image = image
        
        // further information
        self.duration = duration
        self.checkAtIndex = checkAtIndex
        self.paradigm = paradigm
        
        // playback options
        self.shuffle = shuffle
        self.feedback = feedback

        // content
        // either one of those will be filled, the other will be nil, depending of whether it is a recording or a questionnaire scenario
        self.trials = trials
        self.questions = questions
        
        super.init()
    }
    
    // This is used by `ScenarioView` to advance through phases and trials during presentation
    func advance() {
        guard getTrial().object != nil else {return}
        
        if !getTrial().object!.advancePhase() {
            if advanceTrial() {
                getTrial().object!.phaseIndex = 0
            }
        }
    }
    
    // Trial setter and getter
    func advanceTrial() -> Bool {
        guard getTrial().object != nil else {return false}
        
        if (trialsCompleted + 1) < getCount().total {
            trialsCompleted += 1
            scenarioCompleted = false
            return true
        } else {
            trialsCompleted = totalTrials
            scenarioCompleted = true
            return false
        }
    }
    
    func resetTrials() {
        scenarioCompleted = false
        trialsCompleted = 0
    }
    
    /// get index and object of the next trial in the array
    func getTrial() -> (index: Int, object: TrialModel?) {
        guard trials != nil && trialsCompleted < getCount().total else {
            return (index: -1, object: nil)
        }
        return (index: trialsCompleted, object: trials![trialsCompleted])
    }
    
    /// this is used for display purposes in home view and detail view
    func getDuration() -> (total: Double, remaining: Double, block: Double) {
        var total = 0.0
        var remaining = 0.0
        var block = 0.0
        
        switch type {
        case .recording:
            for (c,trial) in trials!.enumerated() {
                var duration = 0.0
                // set a default value for TTS trials
                if trial.duration == 0 {
                    duration = 7
                } else {
                    duration = trial.duration
                }
                // add a fixed value for fitting and checkUp
                duration += 30
                
                total += duration
                c <= checkAtIndex! ? (block += duration) : ()
                c > trialsCompleted ? (remaining += duration) : ()
            }
        case .questionnaire:
            total = Double(questions!.count * 40)
            block = total
            remaining = total
//            if !scenarioCompleted {
//                remaining = total
//            } else {
//                remaining = 0
//            }
        }
        return (total: total, remaining: remaining, block: block)
    }
    
    func getCount() -> (total: Int, remaining: Int) {
        switch type {
        case .recording:
            return((total: trials!.count, remaining: trials!.count - trialsCompleted))
        case .questionnaire:
            return((total: questions!.count, remaining: questions!.count - trialsCompleted))
        }
    }
}
