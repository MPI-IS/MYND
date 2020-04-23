//
//  CountdownTimer.swift
//  myndios
//
//  Created by Matthias Hohmann on 26.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import UICircularProgressRing

protocol CountdownTimerListener {
    func countdownCompleted(withReason reason: CountdownTimerCompletedReasons)
}
enum CountdownTimerCompletedReasons {
    case timeOut
    case stopped
}

/// UNUSED: `CountdownTimer` was part of the Feedback implementation, it is left here to be expanded upon
@IBDesignable
class CountdownTimer: UICircularProgressRing {
    
    var listener: CountdownTimerListener?
    var timer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setVisuals()
    }
    
    func startTimer(seconds: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: {_ in self.listener?.countdownCompleted(withReason: .timeOut)})
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {self.startProgress(to: 100, duration: 0, completion: {self.startProgress(to: 0, duration: seconds - 0.1)})})
    }
    
    func stopTimer() {
        timer?.invalidate()
        self.startProgress(to: self.currentValue!, duration: 0, completion: {self.listener?.countdownCompleted(withReason: .stopped)})
    }
    
    fileprivate func setVisuals() {
        startProgress(to: 100, duration: 0)
        showFloatingPoint = false
        shouldShowValueText = false
        minValue = 0
        maxValue = 100
        outerRingColor = UIColor.MP_lightGrey
        innerRingColor = UIColor.MP_Grey
        outerRingWidth = 0.0
        innerRingWidth = 5.0
        animationTimingFunction = .linear
        innerCapStyle = CGLineCap.butt
        makeCircular()
        layoutIfNeeded()
        
    }
    
}
