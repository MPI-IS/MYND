//
//  StudyController.swift
//  myndios
//
//  Created by Matthias Hohmann on 02.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation
import ResearchKit
import SwiftyJSON

/// The `StudyController` handles state saving. Progression in the current study is stored as dictionary in user defaults, and retrieved from there when the app is relaunched. Subjects can only progress in the study by successfully completing questionnaires or EEG recordings.
class StudyController: NSObject {
    
    static let shared = StudyController()
    
    private let defaults = UserDefaults.standard
    var currentStudy: StudyModel?
    
    /**
     Load and set a study with a given enum. Create save file if it doesnt exist, or load an exisiting one
     */
    func loadAndSetStudy(_ study: Studies) {
        currentStudy = StudyModel(study)
        
        // Check if entry for this study already exists, otherwise create one
        if defaults.dictionary(forKey: study.rawValue) == nil {
            var trialsCompleted = [Int]()
            var scenariosCompletedBool = [Bool]()
            //var scenarioInfo = [(completed: Bool, trialsCompleted: Int)]()
            for _ in currentStudy!.sessions {
                trialsCompleted.append(0)
                scenariosCompletedBool.append(false)
                //scenarioInfo.append((completed: false, trialsCompleted: 0))
            }
            let dict: [String: Any] = [
                // study level
                "active" : false,
                "enrolled" : false,
                "scenariosCompleted": 0,
                "trialsCompleted": trialsCompleted,
                "scenariosCompletedBool": scenariosCompletedBool
            ]
            defaults.set(dict, forKey: study.rawValue)
        }
        loadOrOverrideCurrentStudyProgress()
    }
    
    /**
     Load a save file from user defaults and store the values in the study model of current study
     */
    func loadOrOverrideCurrentStudyProgress() {
        // Make sure the current study is not nil and the dictionary exists
        guard currentStudy != nil else {return}
        guard let progress = defaults.dictionary(forKey: currentStudy!.study.rawValue) else {return}
        
        // Global study progress
        currentStudy?.active = progress["active"] as? Bool ?? false
        currentStudy?.enrolled = progress["enrolled"] as? Bool ?? false
        currentStudy?.scenariosCompleted = progress["scenariosCompleted"] as? Int ?? 0
        currentStudy?.currentDay = progress["currentDay"] as? Int ?? 1
        currentStudy?.currentDayTimeOut = progress["currentDayTimeOut"] as? Date ?? nil
        
        // Individual scenario progress
        let trialsCompleted = progress["trialsCompleted"] as? [Int] ?? [0]
        let scenariosCompletedBool = progress["scenariosCompletedBool"] as? [Bool] ?? [false]
        guard trialsCompleted.count == currentStudy?.sessions.count,
        scenariosCompletedBool.count == currentStudy?.sessions.count else {
            print("study model was altered, resetting progress")
            defaults.removeObject(forKey: currentStudy!.study.rawValue)
            loadAndSetStudy(.mynd_example)
            return
        }
        
        for (c,n) in currentStudy!.sessions.enumerated() {
            n.trialsCompleted = trialsCompleted[c]
            if n.trialsCompleted >= n.totalTrials || scenariosCompletedBool[c] {
                n.scenarioCompleted = true
            }
        }
    }
    
    /**
     Save user values from the current study model in user defaults
     */
    func saveCurrentStudyProgress() {
        // Make sure the current study is not nil and the dictionary exists
        guard currentStudy != nil else {return}
        guard var progress = defaults.dictionary(forKey: currentStudy!.study.rawValue) else {return}
        
        progress["active"] = currentStudy?.active
        progress["enrolled"] = currentStudy?.enrolled
        progress["scenariosCompleted"] = currentStudy?.scenariosCompleted
        progress["currentDay"] = currentStudy?.currentDay
        progress["currentDayTimeOut"] = currentStudy?.currentDayTimeOut
        
        var trialsCompleted = [Int]()
        for (_,n) in currentStudy!.sessions.enumerated() {
            trialsCompleted.append(n.trialsCompleted)
        }
        
        var scenariosCompletedBool = [Bool]()
        for (_,n) in currentStudy!.sessions.enumerated() {
            scenariosCompletedBool.append(n.scenarioCompleted)
        }
        
        progress["trialsCompleted"] = trialsCompleted
        progress["scenariosCompletedBool"] = scenariosCompletedBool
        defaults.set(progress, forKey: currentStudy!.study.rawValue)
    }
}









