//
//  ProgressView.swift
//  myndios
//
//  Created by Matthias Hohmann on 26.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import UICircularProgressRing

/// UNUSED: `ProgressView` was part of the Feedback implementation, it is left here to be expanded upon
@IBDesignable
class ProgressView: UIView {
    
    var endedLastSessionAt: Date! = nil
    var startNextSessionAt: Date! = nil
    var isTimerRunning: Bool = false
    
    var countdown: CountdownTimer! = nil
    var progress: UICircularProgressRing! = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setVisuals()
    }
    
    // TODO: This does not work yet
    func startTimer(lastSessionEndedAt last: Date, nextSessionStartsAt next: Date) {
        let totalTimetoNext = next.timeIntervalSince(last)
        let currentTimetoNext = totalTimetoNext - Date().timeIntervalSince(last)
        print(totalTimetoNext, currentTimetoNext)
        countdown.maxValue = CGFloat(totalTimetoNext)
        self.countdown.startProgress(to: CGFloat(currentTimetoNext), duration: 0, completion: {
            self.countdown.startProgress(to: 0, duration: 5)
            })
    }
    
    // TODO: This does not work yet
    func stopTimer() {
        countdown.startProgress(to: countdown.currentValue!, duration: 0)
    }
    
    func updateProgress(completed: Int, total: Int) {
        progress.maxValue = CGFloat(total)
        progress.startProgress(to: CGFloat(completed), duration: 0.3)
        if completed == total {
            progress.outerRingColor = .MP_lightGrey
            progress.innerRingColor = .MP_Green
        } else {
            progress.outerRingColor = UIColor.MP_lightBlue
            progress.innerRingColor = UIColor.MP_Blue
        }
    }
    
    fileprivate func setVisuals() {
        layoutIfNeeded()
        countdown = CountdownTimer(frame: bounds)
        countdown.minValue = 0
        countdown.maxValue = 0
        countdown.backgroundColor = UIColor.clear
        progress = UICircularProgressRing(frame: bounds.insetBy(dx: 10, dy: 10))
        progress.showFloatingPoint = false
        progress.shouldShowValueText = false
        progress.innerCapStyle = CGLineCap.butt
        progress.outerRingWidth = 30.0
        progress.innerRingWidth = 30.0
        progress.innerRingSpacing = -progress.outerRingWidth * 2
        progress.outerBorderWidth = 0
        progress.minValue = 0
        countdown.makeCircular()
        progress.makeCircular()
        layoutIfNeeded()
    
        self.addSubview(countdown)
        self.addSubview(progress)
        self.makeCircular()
        
    }
}
