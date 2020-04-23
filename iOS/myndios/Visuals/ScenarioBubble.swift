//
//  ScenarioBubble.swift
//  myndios
//
//  Created by Matthias Hohmann on 31.07.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import UICircularProgressRing
import M13Checkbox

/// The round thumbnail of the home view cell, in detailview and pauseview is defined in `ScenarioBubble`. It features progress display and can be used as a button in developer-mode to advance or reset progress quickly.
@IBDesignable class ScenarioBubble: UIView {
    
    @IBInspectable var imageView: UIImageView!
    @IBInspectable var progressView: UICircularProgressRing!
    @IBInspectable var checkbox: M13Checkbox!
    @IBInspectable var remainingTrialsLabel: UILabel!
    
    // Interacting with home view - set if this bubble is part of a home view cell, unsused in detail view and pause view
    weak var homeViewCell: HomeViewCell?
    weak var homeView: HomeViewCellDelegate?
    
    let defaults = UserDefaults.standard
    var scenario: ScenarioModel!
    
    private var initialized: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureVisuals()
    }
    
    func setScenario(_ session: ScenarioModel?) {
        guard let session = session else {return}
        self.scenario = session
        
        // configure visuals the first time that this function is called
        if imageView == nil || progressView == nil || checkbox == nil || remainingTrialsLabel == nil {configureVisuals()}
        
        // update Image
        imageView.image = session.image
        progressView.maxValue = CGFloat(session.getCount().total)
        updateProgress()
    }
    
    func updateProgress(completion: (()->())? = nil) {
        if scenario.getCount().remaining > 0 {
            checkbox.checkState == .checked ? (checkbox.setCheckState(.unchecked, animated: true)) : ()
        }
        
        progressView.startProgress(to: CGFloat(scenario.trialsCompleted), duration: 0.3, completion: { [weak self] in
            guard let strongSelf = self else {return}
            let minutes = Int((strongSelf.scenario.getDuration().remaining / 60).rounded(.up))
            strongSelf.remainingTrialsLabel.text = "\(minutes)"
            if minutes == 0 {
                strongSelf.remainingTrialsLabel.isHidden = true
            } else {
                strongSelf.remainingTrialsLabel.isHidden = false
            }
            
            if strongSelf.scenario.getCount().remaining == 0 {
                strongSelf.checkbox.setCheckState(.checked, animated: true)
            }
            completion?()
        })
    }
    
    func configureVisuals() {
        // If subviews have been added before, remove them
        autoresizesSubviews = true
        
        // trial progress
        imageView = UIImageView(frame: bounds.insetBy(dx: 220, dy: 220))
        imageView.contentMode = .scaleAspectFill
        
        progressView = UICircularProgressRing(frame: bounds)
        progressView.showFloatingPoint = false
        progressView.shouldShowValueText = false
        
        progressView.innerCapStyle = CGLineCap.butt
        
        progressView.minValue = 0
        
        // Label that displays remaining trials
        remainingTrialsLabel = UILabel(frame: bounds)
        remainingTrialsLabel.textAlignment = .center
        remainingTrialsLabel.textColor = .white
        
        // checkbox when scenario was completed
        checkbox = M13Checkbox(frame: bounds)
        checkbox.backgroundColor = UIColor.clear
        checkbox.stateChangeAnimation = .bounce(.fill)
        checkbox.tintColor = UIColor.MP_Green
        checkbox.boxLineWidth = 0
        
        self.addSubview(imageView)
        self.addSubview(progressView)
        self.addSubview(remainingTrialsLabel)
        self.addSubview(checkbox)
        
        // Gesture recognizers for developer interaction
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(increaseTrialCount(sender:)))
        self.addGestureRecognizer(tapGesture)
        
        let holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(resetTrialCount(sender:)))
        self.addGestureRecognizer(holdGesture)
        
    }
    
    /// only possible in developer mode
    @objc func increaseTrialCount(sender: UITapGestureRecognizer) {
        guard defaults.bool(forKey: "isDeveloperModeEnabled") else {return}
        
        // Set self to active session
        homeView?.homeViewCell(homeViewCell, setActiveForSession: scenario)
        
        // Advance trials for recording
        if scenario.type == .recording {
            for _ in 1...scenario.checkAtIndex! {
                _ = scenario.advanceTrial()
            }
        // If it is a questionnaire, just progress one
        } else if scenario.type == .questionnaire {
            scenario.trialsCompleted = scenario.questions!.count
            scenario.scenarioCompleted = true
        }
        
        homeView?.homeViewCell(homeViewCell, didUpdateProgressForSession: scenario)
    }
    
    /// only possible in developer mode
    @objc func resetTrialCount(sender: UITapGestureRecognizer) {
        guard defaults.bool(forKey: "isDeveloperModeEnabled") else {
            return
        }
        
        scenario.resetTrials()
        
        // Set self to active session
        homeView?.homeViewCell(homeViewCell, setActiveForSession: scenario)
        defaults.set(0, forKey: "currentRunIndex")
        
        homeView?.homeViewCell(homeViewCell, didUpdateProgressForSession: scenario)        
    }
    
    // This needs to be done in order to get the correct bounds for making the view circular
    override func layoutSubviews() {
        super.layoutSubviews()
        self.clipsToBounds = true
        remainingTrialsLabel.font = UIFont.systemFont(ofSize: bounds.height / 2.5, weight: .bold)
        if !initialized {
            initialized = true
            subviews.forEach {
                $0.scaleToFillSuperView(withConstant: 0.0)
                $0.isUserInteractionEnabled = false
            }
            
            progressView.innerRingWidth = bounds.height * 0.05
            progressView.innerRingSpacing = -progressView.innerRingWidth * 2
            progressView.outerBorderWidth = 0
            progressView.innerRingColor = .MP_Blue
            
            progressView.outerRingWidth = progressView.innerRingWidth
            progressView.outerRingColor = .MP_Grey
        }
        self.makeCircular()
    }
}


