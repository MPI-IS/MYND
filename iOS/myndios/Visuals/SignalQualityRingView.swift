//
//  SignalQualityRingView.swift
//  myndios
//
//  Created by Matthias Hohmann on 26.02.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import UICircularProgressRing
import M13Checkbox

enum SignalQualityRingViewState {
    case idle
    case inactive
    case active
}

/// `SignalQualityRingView`s display signal quality in real-time. They can be in `idle` state, in which case they are just presented as outlines, `inactive`, where they get updated in gray color, and `active`, where they reflect signal quality with red, yellow, and green colors. The also feature a checkbox that can be enabled to display when progress reaches 100.
class SignalQualityRingView: UICircularProgressRing {
    
    var state: SignalQualityRingViewState = .idle
    var progress: CGFloat = 0.0
    var isCheckboxActivated: Bool = true
    var checkbox: M13Checkbox!
    var imageView: UIImageView!
    
    func setState(to state: SignalQualityRingViewState) {
        self.state = state
        if isCheckboxActivated && progress < 100.00 {
            checkbox.setCheckState(.unchecked, animated: true)
        }
        switch state {
        case .idle:
            startProgress(to: 0, duration: 0)
            if isCheckboxActivated && progress < 100.00 {
                checkbox.setCheckState(.unchecked, animated: true)
            }
            checkbox.tintColor = UIColor.gray
            innerRingColor = UIColor.lightGray
            imageView.isHidden = true
        case .active:
            checkbox.tintColor = UIColor.MP_Green
            updateProgressIfNeeded(duration: 0.1)
            imageView.isHidden = false
        case .inactive:
            checkbox.tintColor = UIColor.gray
            innerRingColor = UIColor.lightGray
            updateProgressIfNeeded(duration: 0.1)
            imageView.tintColor = UIColor.lightGray
            imageView.isHidden = false
        }
    }
    
    func setOptionalImage(_ image: UIImage) {
        imageView.image = image
        imageView.image = imageView.image!.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = .gray
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setVisuals()
    }
    
    override func startProgress(to value: CGFloat, duration animationDuration: TimeInterval, completion: UICircularProgressRing.ProgressCompletion? = nil) {
        if progress != value {
            progress = value
            updateProgressIfNeeded(duration: animationDuration, completion: completion)
        }
    }
    
    fileprivate func updateProgressIfNeeded(duration animationDuration: TimeInterval, completion: UICircularProgressRing.ProgressCompletion? = nil) {
        
        if state == .active {
            var color = UIColor.MP_Grey
            switch progress {
            case _ where progress < 40:
                color = UIColor.MP_Red
            case _ where progress < 70:
                color = UIColor.MP_Orange
            default:
                color = UIColor.MP_Green
            }
            
            innerRingColor = color
            imageView.tintColor = color
            
        }
        if state != .idle {
            if isCheckboxActivated && progress >= 100 {
                checkbox.setCheckState(.checked, animated: true)
            }
            super.startProgress(to: progress, duration: animationDuration, completion: completion)
        }
    }
    
    fileprivate func setVisuals() {
        isHidden = true
        showFloatingPoint = false
        shouldShowValueText = false
        backgroundColor = .white
        
        // Optional UIImageView
        imageView = UIImageView(frame: bounds)
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        
        // CheckBox
        checkbox = M13Checkbox(frame: bounds.insetBy(dx: innerRingWidth, dy: innerRingWidth))
        checkbox.backgroundColor = UIColor.clear
        checkbox.stateChangeAnimation = .bounce(.fill)
        checkbox.tintColor = UIColor.MP_Green
        checkbox.boxLineWidth = 0
        addSubview(checkbox)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        innerRingWidth = 0.05 * bounds.width
        outerRingWidth = innerRingWidth
        innerRingSpacing = -2 * innerRingWidth
        outerBorderWidth = 0
        innerCapStyle = CGLineCap.butt
        
        subviews.forEach {
            $0.scaleToFillSuperView(withConstant: 0.0)
            $0.isUserInteractionEnabled = false
            $0.makeCircular()
        }
        
        makeCircular()
    }
}
