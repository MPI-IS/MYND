//
//  FeedbackController.swift
//  myndios
//
//  Created by Matthias Hohmann on 19.09.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import RxSwift
import Surge
import Accelerate

enum FeedbackMode: String {
    case calibrating
    case giving
}

protocol FeedbackControllerDelegate: class {
    func feedbackController(_ feedbackController: FeedbackController, didUpdateFeedbackValue value: CGFloat)
}

/// UNUSED. The feedback controller was implemented to give feedback during a recording. It remained unused at the time of development, but is left in the code to extend it in the future. This is called in `ScenarioView`, and controls the corresponding `FeedbackView`.
class FeedbackController: NSObject {

    var mode: FeedbackMode!
    weak var processingDelegate: ProcessingDelegate?
    weak var feedbackDelegate: FeedbackControllerDelegate?
    
    private var disposeBag = DisposeBag()
    
    // values updated during calibration
    private var cValues = [Float]()
    private var cMean: Float = 0.0
    private var cStd: Float = 0.0
    
    init(processingDelegate: ProcessingDelegate) {
        super.init()
        self.processingDelegate = processingDelegate
    }
    
    func start(_ mode: FeedbackMode) {
        guard mode != self.mode,
            processingDelegate != nil else {return}
        
        self.mode = mode
        print("[Feedback Delegate] \(mode.rawValue) Current Mean: \(cMean) Current STD: \(cStd)")
        
        disposeBag = DisposeBag()
        processingDelegate?.start(mode: .noiseDetection)
        processingDelegate?.bp.subscribe({[weak self] bp in self?.updateFeedback(withValue: bp.element!)}).disposed(by: disposeBag)
    }
    
    func updateFeedback(withValue values: [Float]) {
        
        // take only the rear channels
        // TODO: Make this flexible in the future
        let value = Surge.mean([values[0],values[3]])
        
        switch mode! {
        case .calibrating:
            cValues.append(value)
            cMean = Surge.mean(cValues)
            cStd = Surge.std(cValues)
        case.giving:
            let zscoredValue = (value - cMean) / cStd
            feedbackDelegate?.feedbackController(self, didUpdateFeedbackValue: CGFloat(zscoredValue + 3))
        }
    }
    
    func stop() {
        disposeBag = DisposeBag()
    }
    
}
