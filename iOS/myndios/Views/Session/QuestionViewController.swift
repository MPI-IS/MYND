//
//  QuestionViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 21.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import SwiftyJSON
import ResearchKit

/// If the selected scenario is a questionnaire, Home view instantiates a `QuestionView` container. In addition to the shared views, presenting the questionnaire items is handled by a *ResearchKit* `ORKTaskViewController`, and collecting results is implemented in `ORKTaskViewControllerDelegate`. Results are merged with some meta-information from the session and passed to `StorageController` to be stored as JSON. If data was stored successfully, the study is advanced. See "models -> questionnaires" for more details, and `initial_en.json` for an example questionnaire.
class QuestionViewController: MNDSessionVCBase {
    
    var orkTask: ORKTaskViewController?
    
    static func make(session: ScenarioModel?) -> QuestionViewController {
        let viewController = QuestionViewController()
        viewController.setSession(session: session)
        return viewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(endSession))
    }
    
    override func setSession(session: ScenarioModel?) {
        guard let session = session,
            session.type == .questionnaire else {return}
        super.setSession(session: session)
        
        let task = ORKOrderedTask(identifier: session.title, steps: session.questions)
        orkTask = ORKTaskViewController(task: task, restorationData: nil, delegate: self)
        
        flowVC.sessionFlow[.detail] = DetailViewController.make(self, completion: {[weak self] in self?.goTo(phase: .survey)})
        flowVC.sessionFlow[.survey] = orkTask
        flowVC.sessionFlow[.upload] = UploadViewController.make(TransferController.shared, completion: {[weak self] in self?.goTo(phase: .finish)})
        flowVC.sessionFlow[.finish] = StepViewController.make(self, mode: "QuestionnaireFinish", completion: {[weak self] in self?.endSession()})
        goTo(phase: .detail)
    }
    
    @objc func endSession() {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    func logItems() -> [String: Any] {
        var items = [String: Any]()
        items["title"] = session.scenario.rawValue
        items["day"] = session.day
        items["sessionStartTime"] = sessionStartTime.timeStamp()
        items["subjectID"] = defaults.string(forKey: "uuid")
        items["sessionID"] = session.index
        items["runID"] = defaults.integer(forKey: "currentRunIndex")
        items["locale"] = NSLocale.autoupdatingCurrent.languageCode
        return items
    }
}

/// collect results after completion
extension QuestionViewController: ORKTaskViewControllerDelegate {
    
    /// say each question when it appears
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        guard let step = stepViewController.step,
            step.title != nil,
            step.text != nil else {return}
        if step.title!.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {TTSController.shared.say("\(step.text!)")}
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {TTSController.shared.say("\(step.title!). \(step.text!)")}
        }
        
    }
    
    /// stop saying the question when it dissapears
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillDisappear stepViewController: ORKStepViewController, navigationDirection direction: ORKStepViewControllerNavigationDirection) {
        TTSController.shared.stop()
    }
    
    /// collect results as dictionary. Results are merged with some meta-information from the session and passed to `StorageController` to be stored as JSON. If data was stored successfully, the study is advanced.
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        guard reason == .completed else {goTo(phase: .cancel); return}
        
        let results = taskViewController.result.results as! [ORKStepResult]
        var dict = [String: Any]()
        
        for stepResult: ORKStepResult in results {
            guard let answer = stepResult.results as? [ORKQuestionResult] else {break}
            for choice in answer {
                let a = "\(choice.answer ?? "no answer")".alphanumeric.trimmingCharacters(in: .whitespaces)
                dict[stepResult.identifier] = a
            }
        }
        dict.merge(logItems()) {d1,d2 in return d1}
        // If data could be stored, advance the study
        if StorageController.shared.storeQuestionnaire(dict) != -1 {
            TransferController.shared.uploadPending()
            
            sessionResult = .didFinishScenario
            StudyController.shared.currentStudy!.setCurrentDayTimeOut(to: Date().addingTimeInterval(defaults.double(forKey: "timeOutTimeInterval")))
            defaults.set(defaults.integer(forKey: "currentRunIndex") + 1, forKey: "currentRunIndex")
            session.trialsCompleted = session.getCount().total
            session.scenarioCompleted = true
            _ = StudyController.shared.currentStudy!.advanceSession()
            if StudyController.shared.currentStudy!.checkCompletion().day {
                sessionResult = .didFinishDay
            }
            StudyController.shared.saveCurrentStudyProgress()
            
            goTo(phase: .upload)
        }
    }
}
