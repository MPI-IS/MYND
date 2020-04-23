//
//  StudyModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 13.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import Foundation
import ResearchKit
import SwiftyJSON

/**
The `Studies` enum contains all possible studies on the system (at the time of development, this was only the MYND study)
*/
enum Studies: String {
    case mynd_example
    static let allValues = [mynd_example]
}

/**
 A time out functionality is implemented to control the time in which subjects complete scenarios of a given day. After successfully completing either a questionnaire or a recording, the respective container views call `StudyModel -> setCurrentDayTimeOut` and set the date to now + however many seconds were indicated in `Setup`. After this, a footer will be present in `HomeView` that displays the remaining time.
 
This enum contains states that are necessary for study progression.
 - none: no time out set, subjects can take as long as they want
 - wait: a time out was set until subjects need to complete sessions, or until the screen is locked if subjects already completed all sessions
 - timeOut: the currentTime is later than the set time out date, so the study advances to the next day and resets itself to `none`.
*/
enum DayTimeOutState: String {
    case none, timeOut, wait
}

/**
The `StudyModel` is a container for all scenarios that are presented to the user during the course of the study. It also tracks completed scenarios.
*/
class StudyModel: NSObject {
    
    let study: Studies
    
    // visuals (localized)
    let name: String
    let text: String
    
    // user parameters
    var enrolled: Bool = false
    var active: Bool = false
    var scenariosCompleted: Int = 0
    var totalScenarios: Int = 0
    var currentDay: Int = 1
    var currentDayTimeOut: Date?
    
    // consent steps are attached here and loaded during initalization
    var consent: (document: ORKConsentDocument?, steps: [ORKStep]?)
    // sessions can either be questionnaires or recordings
    var sessions = [ScenarioModel]()
    
    init(_ study: Studies) {
        
        self.study = study
        self.name = study.rawValue
        
        switch study {
        case .mynd_example:
            
            self.text = "This an example study that can be used as a blueprint for future work"
            
            // The study protocoll is created here. `ScenarioModel` has static functions to generate the desired scenarios and append them for the desired day.
            // day 1
            print(sessions.endIndex)
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.initial, forDay: 1, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 1, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 1, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 1, atIndex: self.sessions.endIndex))
            
            // day 2
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 2, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 2, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 2, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 2, atIndex: self.sessions.endIndex))
            
            // day 3
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 3, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.music, forDay: 3, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 3, atIndex: self.sessions.endIndex))
            
            // day 4
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 4, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 4, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 4, atIndex: self.sessions.endIndex))
            
            // day 5
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 5, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 5, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.music, forDay: 5, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 5, atIndex: self.sessions.endIndex))
            
            // day 6
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 6, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 6, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 6, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.memories, forDay: 6, atIndex: self.sessions.endIndex))
            
            // day 7
            self.sessions.append(ScenarioModel.makeQuestionnaireScenario(.motivation, forDay: 7, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.rest, forDay: 7, atIndex: self.sessions.endIndex))
            self.sessions.append(ScenarioModel.makeRecordingScenario(.music, forDay: 7, atIndex: self.sessions.endIndex))
            
            
        }
        self.totalScenarios = self.sessions.count
        
        // Consent
        
        // Check language
        let locale = NSLocale.autoupdatingCurrent.languageCode
        
        // Make sure JSON exists
        // The consent is generated here. `DocumentController` has the necessary static functions and generates the consent based on a localized JSON file.
        guard let consentJSON = DocumentController.shared.returnJSON("\(study)_consent_\(locale ?? "en")") else { print("Could not load \(study)_consent_\(locale ?? "en")");return}
        // Create Consent, crashes if unavailable
        consent = try! QuestionGenerator.shared.buildConsentWithJSON(consentJSON)
        
    }
    
    func resetStudy() {
        sessions.forEach {
            $0.trialsCompleted = 0
            $0.scenarioCompleted = false
        }
        scenariosCompleted = 0
        setCurrentDayTimeOut(to: nil)
        currentDay = 1
    }
    
    // set the time out, after which subjects can proceed to the next day of sessions
    func setCurrentDayTimeOut(to date: Date?, setUserNotification notification: Bool = true) {
        // if calling class wants to set timeOut to nil, do so
        if date == nil {
            currentDayTimeOut = nil
        } else if currentDayTimeOut == nil{
           // else only set the timeOut date if there is none set
           currentDayTimeOut = date
            // set an iOS notification for that date, such that the user is reminded to come back to the application
            notification ? (BannerController.shared.scheduleUserNotificationForDay(onDate: currentDayTimeOut!)) : ()
        }
    }
    
    // get the time out date and return the current state, as well as reminaing time
    func checkForDayTimeOut() -> (state: DayTimeOutState, timeInterval: TimeInterval) {
        // if there is no timeOut set, return none
        guard let timeOut = currentDayTimeOut else {return (state: .none, timeInterval: 0.0)}
        let currentTime = Date()
        // if the timeOut was passed, return timeOut and reset
        if currentTime >= timeOut {
            return (state: .timeOut, timeInterval: 0.0)
        } else {
            // if we have not passed the Date, return wait
            return (state: .wait, timeInterval: timeOut.timeIntervalSince(currentTime))
        }
    }
    
    // complete the current day
    func completeDay() {
        // mark current day as complete
        getDay().forEach {
            $0.scenarioCompleted = true
        }

        // set any remaining timeOut to nil
        setCurrentDayTimeOut(to: nil)
    }
    
    /// advance to the next day in the study
    func advanceDay(toInt index: Int? = nil) {
        var i = 0
        index != nil ? (i = index!) : (i = currentDay + 1)
        
        // if there is no session for the requested day, return
        guard !(sessions.filter {$0.day == i }).isEmpty else {return}
        
        // increase day count
        currentDay = i
        resetDay()
    }
    
    /// reset progress of the day, only called privately when a day advanced to make sure there is no leftover progress
    func resetDay() {
        // if, for whatever reason, the next day contains completion, set it to false
        getDay().forEach {
            $0.scenarioCompleted = false
            $0.trialsCompleted = 0
        }
        // make sure the index for the next day is on top
        setSessionIndex(to: getDay().first!.index)
        
        // set any remaining timeOut to nil
        setCurrentDayTimeOut(to: nil)
        
        _ = checkCompletion()
    }
    
    /// this function is called at the end of a recording, if all trials of a scenario were completed
    func advanceSession() -> Bool {
        guard scenariosCompleted + 1 < sessions.count else {
            scenariosCompleted = totalScenarios - 1
            return false
        }
        scenariosCompleted += 1
        return true
    }
    
    func setSessionIndex(to index: Int) {
        guard index < sessions.count else {
            return
        }
        scenariosCompleted = index
    }
    
    func getSession() -> ScenarioModel? {
        guard scenariosCompleted < sessions.count else {
            return nil
        }
        return sessions[scenariosCompleted]
    }
    
    func getDay() -> [ScenarioModel] {
        var day = [ScenarioModel]()
        for session in sessions {
            if session.day == currentDay {
                day.append(session)
            }
        }
        return day
    }
    
    func getDuration() -> (total: Double, remaining: Double, dayTotal: Double, dayRemaining: Double) {
        var total = 0.0
        var remaining = 0.0
        var dayTotal = 0.0
        var dayRemaining = 0.0
        for (c,session) in sessions.enumerated() {
            total += session.getDuration().total
            session.day == currentDay ? (dayTotal += session.getDuration().total) : ()
            session.day == currentDay ? (dayRemaining += session.getDuration().remaining) : ()
            c > scenariosCompleted ? (remaining += session.getDuration().remaining) : ()
        }
        return (total: total, remaining: remaining, dayTotal: dayTotal, dayRemaining: dayRemaining)
    }
    
    func checkCompletion() -> ((day: Bool, study: Bool)) {
        var dayCompletion = true
        var studyCompletion = true
        for scenario in sessions {
            if scenario.day == currentDay {
                scenario.scenarioCompleted ? () : (dayCompletion = false)
            }
            scenario.scenarioCompleted ? () : (studyCompletion = false)
        }
        return ((day: dayCompletion, study: studyCompletion))
    }
    
}
