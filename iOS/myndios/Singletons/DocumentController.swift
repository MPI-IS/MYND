//
//  DocumentController.swift
//  myndios
//
//  Created by Matthias Hohmann on 14.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation
import SwiftyJSON
import ResearchKit

/// this extension of NSNotificationCenter is used throughout the application to give feedback messages to the user or developer, mostly if something goes wrong
extension NotificationCenter {
    // possible styles: info, error, success
    func postBanner(message: String, style :String = "info", say: Bool = false) {
        let n = Notification.init(name: Notification.Name("bannerMessage"), object: nil, userInfo: ["message": message, "style": style, "say": say])
        DispatchQueue.main.async {
            self.post(n)
        }
    }
    func cancelBanner() {
        let n = Notification.init(name: Notification.Name("bannerMessageCanceled"), object: nil, userInfo: nil)
        DispatchQueue.main.async {
            self.post(n)
        }
    }
}

/**
 The `DocumentController` contains a selection of functions that deal with JSON files for various purposes. It is called throughout the whole application. See comments on each function for their specific  use case.
 */
class DocumentController: NSObject {
    
    static let shared = DocumentController()
    
    private let nc = NotificationCenter.default
    private let defaults = UserDefaults.standard
    
    /// load the requested JSON file, return nil if cannot be found
    func returnJSON(_ file: String) -> JSON? {
        var json: JSON?
        if let jsonFile = Bundle.main.url(forResource: file, withExtension: "json") {
            if let jsonData = try? Data(contentsOf: jsonFile) {
                do {
                    json = try JSON(data: jsonData)
                } catch {
                    nc.postBanner(message: "Could not load JSON")
                }
            }
        }
        return json
    }
    
    /// Questionnaire scenarios are directly loaded from a *localized JSON file* through the `DocumentController`. JSON files contain `title`, `text`, and `image` name of the scenario, as well as the questions. These question items are handed to the `QuestionGenerator` class. Please refer to the existing JSON documents, e.g., `motivation_en.json` for the general structure of these question items. Instructions without answer-options, short text answers, multiple choice, date answers, and numeric answers are supported.
    func loadQuestionnaire(forScenarioType type: Scenario) -> (title: String, text: String, imageNamed: String, steps: [ORKStep]) {
        
        var questionnaire = (title: "", text: "", imageNamed: "", steps: [ORKStep]())
        
        // Check language
        let locale = NSLocale.autoupdatingCurrent.languageCode
        
        // Make sure JSON exists
        guard let questionnaireJSON = returnJSON("\(type.rawValue)_\(locale ?? "en")") else {
            return questionnaire
        }
        
        questionnaire.title = questionnaireJSON["title"].string ?? "No Title"
        questionnaire.text = questionnaireJSON["text"].string ?? "No Description"
        questionnaire.imageNamed = questionnaireJSON["image"].string ?? ""
        questionnaire.steps += QuestionGenerator.shared.buildQuestionStepsWithJSON(questionnaireJSON["questions"].array!)
        return questionnaire
    }
    
    
    /// Preparation items defined in the `StepModel`. They are prepared by the `DocumentController` class and presented before the EEG recording procedure. Please refer to `Steps_en.json` for the general structure of these items. Hardware preparation steps can be *regular* or *short*, which was implemented to progress faster through preparation after having done it several times. Videos or images can be presented alongside a preparation step. Optionally, a step can be locked until it receives a `CompletionSignal` from the device, and a `CompletionFunction` can be executed as well afterwards.
    func loadSteps(for mode: String) -> [StepModel] {
        var steps = [StepModel]()
        
        // Check language
        let locale = NSLocale.autoupdatingCurrent.languageCode
        guard let json = returnJSON("Steps_\(locale ?? "")") else {
            nc.postBanner(message: "Could not load JSON for Steps_\(locale ?? "")", style: "devError")
            return steps
        }
        
        for itemL1 in json["modes"].array! {
            if itemL1["mode"].string! == mode {
                for itemL2 in itemL1["instructions"].array! {
                    let step = StepModel(
                        itemL2["name"].string!,
                        itemL2["pictureName"].string,
                        itemL2["instruction"].string!,
                        itemL2["buttonTitle"].string,
                        itemL2["buttonSuccessTitle"].string,
                        itemL2["timeOut"].double,
                        evaluateSignal(with: itemL2["completionSignal"].string),
                        evaluateFunction(with: itemL2["completionFunction"].string)
                    )
                    steps.append(step)
                }
                break
            }
        }
        return steps
    }
    
    /// see above
    func loadShortSteps(for mode: String) -> [StepModel] {
        var steps = [StepModel]()
        
        // Check language
        let locale = NSLocale.autoupdatingCurrent.languageCode
        guard let json = returnJSON("Steps_\(locale ?? "")") else {
            nc.postBanner(message: "Could not load JSON for Steps_\(locale ?? "")", style: "devError")
            return steps
        }
        
        for itemL1 in json["modes"].array! {
            if itemL1["mode"].string! == mode {
                for itemL2 in itemL1["instructions"].array! {
                    // only look for steps with a short instruction attached
                    if itemL2["short"].string != nil{
                        let step = StepModel(
                            itemL2["name"].string!,
                            itemL2["pictureName"].string,
                            itemL2["short"].string!,
                            itemL2["buttonTitle"].string,
                            itemL2["buttonSuccessTitle"].string,
                            itemL2["timeOut"].double,
                            evaluateSignal(with: itemL2["completionSignal"].string),
                            evaluateFunction(with: itemL2["completionFunction"].string)
                        )
                        steps.append(step)
                    }
                }
                break
            }
        }
        return steps
    }
    
    /// this function is used to map a string in the JSON to its respective enum option. Used during preparation
    func evaluateSignal( with expression: String?) -> DeviceStates? {
        if expression == nil {
            return nil
        }
        return DeviceStates(rawValue: expression!)
    }

    /// this function is used to map a string in the JSON to its respective enum option. Used during fitting
    func evaluateFunction( with expression: String?) -> CompletionFunction? {
        if expression == nil {
            return nil
        }
        return CompletionFunction(rawValue: expression!)
    }
}
