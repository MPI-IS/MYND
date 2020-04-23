//
//  InstructionView.swift
//  myndios
//
//  Created by Matthias Hohmann on 26.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import M13Checkbox
import SwiftyGif

protocol InstructionViewListener {
    func instructionCompleted(instruction: String, withReason reason: InstructionCompletedReasons)
}
enum InstructionCompletedReasons {
    case timeOut
    case success
}

/// UNUSED: `InstructionView` was part of the Feedback implementation, it is left here to be expanded upon
class InstructionView: UIView, CountdownTimerListener {
    
    var listener: InstructionViewListener?
    var wasSucessful: Bool = false
    
    fileprivate var image: UIImageView!
    fileprivate var instruction: String!
    fileprivate var countdown: CountdownTimer!
    fileprivate var checkbox: M13Checkbox!
    fileprivate let gifManager = SwiftyGifManager(memoryLimit: 20)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setVisuals()
    }
    
    func setInstruction(named name: String, withImageNamed imageName: String? = nil, withTimeout timeout: TimeInterval? = nil) {
        instruction = name
        wasSucessful = false
        checkbox.setCheckState(.unchecked, animated: true)
        if imageName != nil {
            if imageName!.contains(".gif") {
                let gif = UIImage(gifName: imageName!)
                self.image.setGifImage(gif, manager: gifManager, loopCount: -1)
            } else {
                self.image.image = UIImage(named: imageName!)
            }
        } else {
            self.image.image = nil
        }
        if timeout != nil {
            timeout! > 0 ? startCountdown(timeout!) : ()
        }
    }
    
    func removeImage() {
        image.image = nil
    }
    
    func success(withDelay delay: TimeInterval = 0.3, blocking: Bool = false) {
        if blocking {
            countdown.isAnimating ? countdown.stopTimer() : ()
            UIApplication.shared.beginIgnoringInteractionEvents()
        }
        wasSucessful = true
        checkbox.setCheckState(.checked, animated: true)
        Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: {_ in
            blocking ? UIApplication.shared.endIgnoringInteractionEvents() : ()
            self.listener?.instructionCompleted(instruction: self.instruction, withReason: .success)
        })
    }
    
    func startCountdown(_ timeout: TimeInterval) {
        
        countdown.startTimer(seconds: timeout)
    }
    
    func stopCountdown() {
       countdown.isAnimating ? countdown.stopTimer() : ()
    }
    
    func countdownCompleted(withReason reason: CountdownTimerCompletedReasons) {
        reason == .timeOut ? listener?.instructionCompleted(instruction: instruction, withReason: .timeOut) : ()
    }
    
    fileprivate func setVisuals() {
        setNeedsLayout()
        image = UIImageView(frame: bounds)
        image.contentMode = .scaleAspectFill
        countdown = CountdownTimer(frame: bounds)
        countdown.backgroundColor = UIColor.clear
        checkbox = M13Checkbox(frame: bounds)
        checkbox.backgroundColor = UIColor.clear
        checkbox.stateChangeAnimation = .bounce(.fill)
        checkbox.tintColor = UIColor.MP_Green
        checkbox.boxLineWidth = 0
        
        addSubview(image)
        addSubview(countdown)
        addSubview(checkbox)


        
        countdown.listener = self
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        makeCircular()
        
        subviews.forEach({$0.scaleToFillSuperView(withConstant: 0); $0.makeCircular()})
        subviews.forEach({$0.isUserInteractionEnabled = false})
        
        
    }
    
}
