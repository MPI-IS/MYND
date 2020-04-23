//
//  QuestionGenerator.swift
//  myndios
//
//  Created by Matthias Hohmann on 22.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import Foundation
import SwiftyJSON
import ResearchKit

extension String: Error {}

/// The `QuestionGenerator` is a collection of functions that take JSON arrays and turn them into concrete objects for display. It handles questionnaires with one function per supported question type. It also generates the consent views that are presented during boarding. See the `inital_en.json` and `mynd_consent_en.json` for examples of the JSON file structures.
class QuestionGenerator: NSObject {
    
    static let shared = QuestionGenerator()
    
    func buildQuestionStepsWithJSON(_ array: [JSON]) -> [ORKStep] {
        var steps = [ORKStep]()
        
        // Go through each question in the question array
        for question in array {
            /// make sure it has an identifier and a type, otherwise return
            guard question["identifier"].string != nil,
                let type = question["type"].string else {break}
            
            // these types of questions are supported. For new question types, a new function must be implemented that specificially handles them
            switch type {
            case "text":
                steps.append(buildTextQuestionStepWithJSON(question))
            case "instruction":
                steps.append(buildInstructionStepWithJSON(question))
            case "mc":
                steps.append(buildMultipleChoiceQuestionWithJSON(question))
            case "date":
                steps.append(buildDateQuestionStepWithJSON(question))
            case "numeric":
                steps.append(buildNumericQuestionStepWithJSON(question))
            default:
                print("type \(type) not supported, question was skipped")
            }
        }
        return steps
    }

    private func buildDateQuestionStepWithJSON(_ question: JSON) -> ORKStep {
        // Set range in which the birthdate must have happened
        var components = DateComponents()
        components.year = -100
        let minDate = Calendar.current.date(byAdding: components, to: Date())
        
        components.year = -18
        let maxDate = Calendar.current.date(byAdding: components, to: Date())
        
        let answer = ORKDateAnswerFormat(style: .date, defaultDate: maxDate, minimumDate: minDate, maximumDate: maxDate, calendar: .current)
        
        let q = ORKQuestionStep(identifier: question["identifier"].string!, title: question["title"].string!, question: nil, answer: answer)
        q.text = question["text"].string!
        if let optional = question["optional"].bool {
            q.isOptional = optional
        }
        return q
    }
    
    private func buildTextQuestionStepWithJSON(_ question: JSON) -> ORKStep {
        let answer = ORKTextAnswerFormat(maximumLength: 30)
        answer.multipleLines = false
        
        // if a specific input type was set, apply it to the keyboard
        if let input = question["input"].string {
            switch input {
            case "word":
                answer.autocapitalizationType = .words
                answer.autocorrectionType = .yes
                answer.keyboardType = .asciiCapable
            case "number":
                answer.keyboardType = .numberPad
            default:
                break
            }
        }
        
        let q = ORKQuestionStep(identifier: question["identifier"].string!, title: question["title"].string!, question: nil, answer: answer)
        q.text = question["text"].string!
        if let optional = question["optional"].bool {
            q.isOptional = optional
        }
        return q
    }
    
    private func buildNumericQuestionStepWithJSON(_ question: JSON) -> ORKStep {
        let answer = ORKNumericAnswerFormat(style: .integer)
        
        let q = ORKQuestionStep(identifier: question["identifier"].string!, title: question["title"].string!, question: nil, answer: answer)
        q.text = question["text"].string!
        if let optional = question["optional"].bool {
            q.isOptional = optional
        }
        return q
    }
    
    private func buildInstructionStepWithJSON(_ instruction: JSON) -> ORKStep {
        let q = ORKInstructionStep(identifier: instruction["identifier"].string!)
        q.text = instruction["text"].string!.withFilledPlaceholders()
        q.title = instruction["title"].string!.withFilledPlaceholders()
        return q
    }
    
    private func buildMultipleChoiceQuestionWithJSON(_ question: JSON) -> ORKStep {
        // create array with answer choices
        var choices = [ORKTextChoice]()
        for choice in question["choices"].array! {
            let textChoice = ORKTextChoice(text: choice["text"].string!.withFilledPlaceholders(), value: choice["value"].int! as NSNumber)
            choices.append(textChoice)
        }
        
        // attach choices to the answer
        let answer = ORKTextChoiceAnswerFormat(style: .singleChoice, textChoices: choices)
        let q = ORKQuestionStep(identifier: question["identifier"].string!, title: question["title"].string!.withFilledPlaceholders(), question: nil, answer: answer)
        q.text = question["text"].string!.withFilledPlaceholders()
        if let optional = question["optional"].bool {
            q.isOptional = optional
        }
        return q
    }
    
    /// generate the consent that is to be presented during boarding
    func buildConsentWithJSON(_ consentJson: JSON) throws -> (document: ORKConsentDocument?, steps: [ORKStep]?) {
        var consent: (document: ORKConsentDocument?, steps: [ORKStep]?)
        
        // make sure JSON file is valid
        guard let title = consentJson["title"].string,
            let steps = consentJson["steps"].array else {throw "Invalid document"}
        
        // Create consent document
        let consentDocument = ORKConsentDocument()
        consentDocument.title = title
        
        // Signatures
        consentDocument.signaturePageTitle = title
        consentDocument.signaturePageContent = consentJson["pageConsent"].string
        consentDocument.addSignature(ORKConsentSignature(forPersonWithTitle: NSLocalizedString("#participant#", comment: ""), dateFormatString: nil, identifier: "ParticipantSignature"))
        
        // Visual Consent Steps
        
        var consentSteps = [ORKStep]()
        var consentSections = [ORKConsentSection]()
        
        // section types
        let consentSectionTypes: [String: ORKConsentSectionType] = [
            "overview" : .overview,
            "dataGathering" : .dataGathering,
            "privacy" : .privacy,
            "dataUse" : .dataUse,
            "timeCommitment" : .timeCommitment,
            "studySurvey" : .studySurvey,
            "studyTasks" : .studyTasks,
            "withdrawing" : .withdrawing,
            "custom" : .custom,
            "onlyInDocument": .onlyInDocument
        ]
 
        for step in steps {
            
            // check for any specific section type that was defined, if not say custom
            let tstring = step["type"].string ?? "custom"
            let t = consentSectionTypes[tstring] ?? .custom
            
            // create the section
            let consentSection = ORKConsentSection(type: t)
            consentSection.content = step["content"].string!
            if  UIDevice.current.userInterfaceIdiom != .pad,
                let summary = step["summary"].string {
                consentSection.summary = summary
            } else {
                consentSection.summary = consentSection.content
                consentSection.customLearnMoreButtonTitle = ""
            }
            
            // if there is a custom title, add it as well
            if let title = step["title"].string {
                consentSection.title = title
            }
            
            consentSections.append(consentSection)
        }
        
        // Add visual consent step
        consentDocument.sections = consentSections
        let visualConsentStep = ORKVisualConsentStep(identifier: "VisualConsentStep", document: consentDocument)
        consentSteps += [visualConsentStep]
        
        // Add consent review step
        for signature in consentDocument.signatures! {
            let reviewConsentStep = ORKConsentReviewStep(identifier: "ConsentReviewStep", signature: signature, in: consentDocument)
            reviewConsentStep.text = NSLocalizedString("#reviewConsent#", comment: "")
            reviewConsentStep.reasonForConsent = NSLocalizedString("#reasonForConsent#", comment: "")
            consentSteps += [reviewConsentStep]
        }
        
        // Additional questions and final remarks during boarding
        consentSteps += buildQuestionStepsWithJSON(consentJson["questions"].array!)
        consentSteps = buildQuestionStepsWithJSON(consentJson["boarding"].array!) + consentSteps
        
        consent = ((document: consentDocument, steps: consentSteps))
        
        return consent
    }
}
