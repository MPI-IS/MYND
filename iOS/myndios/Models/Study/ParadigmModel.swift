//
//  ParadigmModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 02.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation

/// This object is attached to the recorded file. It defines the conditions in a scenario such that information about relevant markers, labels, and trial time can be read directly from the file by an analysis program.
class ParadigmModel: NSObject, Codable {
    let title: String
    let conditionCount: Int
    let conditionLabels: [String]
    let conditionMarkers: [Int]
    let baseMarkers: [Int]
    let baseTime: Int
    let trialTime: Int
    
    init(title: String, conditionLabels: [String], conditionMarkers: [Int], baseMarkers: [Int], baseTime: Int, trialTime: Int) {
        self.title = title
        self.conditionCount = conditionLabels.count
        self.conditionLabels = conditionLabels
        self.conditionMarkers = conditionMarkers
        self.baseMarkers = baseMarkers
        self.baseTime = baseTime
        self.trialTime = trialTime
    }
}
