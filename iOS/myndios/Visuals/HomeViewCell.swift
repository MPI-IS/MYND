//
//  HomeViewCell.swift
//  myndios
//
//  Created by Matthias Hohmann on 24.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit

protocol HomeViewCellDelegate: class {
    func homeViewCell(_ homeViewCell: HomeViewCell?, didUpdateProgressForSession session: ScenarioModel)
    func homeViewCell(_ homeViewCell: HomeViewCell?, didClickButtonForSession session: ScenarioModel)
    func homeViewCell(_ homeViewCell: HomeViewCell?, setActiveForSession session: ScenarioModel)
}

/// One `HomeViewCell` represents one scenario for a given day. A collection of home view cells are loaded by the home view when the app is launched.
class HomeViewCell: UITableViewCell {
    
    @IBOutlet weak var imgHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var sessionIconHeightContstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var sessionTitle: UILabel!
    @IBOutlet weak var sessionSubtitle: UILabel!
    @IBOutlet weak var sessionIcon: ScenarioBubble!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var activeScreen: UIView!
    
    /// this protocol is implemented by the `HomeViewController`
    weak var homeView: HomeViewCellDelegate? {
        get {
            return sessionIcon.homeView
        }
        set {
            sessionIcon.homeView = newValue
        }
    }
    
    /// the scenario that is represented by this cell
    var session: ScenarioModel! = nil
    var active: Bool!
    let defaults = UserDefaults.standard
    
    var activeHeight: CGFloat = 200
    var inactiveHeight: CGFloat = 140
    
    /// visual setup
    func setSession(_ session: ScenarioModel?) {
        guard let session = session else {return}
        self.session = session
        
        sessionIcon.setScenario(session)
        backgroundImage.image = session.image
        sessionTitle.text = session.title
        
        startButton.addTarget(self, action: #selector(didClickButton), for: .touchUpInside)
    }
    
    /// The home view cell changes its appearance when the corresponding scenario is set to "active" (i.e., the next scenario that the subject should record), and if an announcement can be displayed. This is toggled with the `setActive` function.
    func setActive(_ active: Bool = true) {
        //  if a message should be displayed, change the button title to reflect this
        var string = ""
        if self.defaults.bool(forKey: "shouldPresentRemoteMessage") {
            string = NSLocalizedString("#newMessage#", comment: "") + " \u{002709}"
        } else {
            string = NSLocalizedString("#getStarted#", comment: "")
        }
        startButton.title(for: .normal) != string ? (self.startButton.setTitle(string, for: .normal)) :()
        if active != self.active {
            self.active = active

            if active {
                self.imgHeightConstraint.constant = activeHeight
                UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                    self.activeScreen.alpha = 0 // Here you will get the animation you want
                }, completion: { _ in
                    self.activeScreen.isHidden = true // Here you hide it when animation done
                    self.startButton.isHidden = false
                })
            } else {
                activeScreen.isHidden = false
                startButton.isHidden = true
                self.imgHeightConstraint.constant = inactiveHeight
                UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                    self.activeScreen.alpha = 0.8 // Here you will get the animation you want
                }, completion: nil)
            }
            sessionIconHeightContstraint.constant = inactiveHeight * 0.8
        }
    }
    
    /// display the remaing minutes of this scenario
    func setRemainingMinutes() {
        let seconds  = session.getDuration().remaining
        if seconds > 0 && seconds <= 60 {
            sessionSubtitle.text = NSLocalizedString("#1minuteRemaining#", comment: "")
        } else if seconds <= 0 {
            sessionSubtitle.text = NSLocalizedString("#completed#", comment: "")
        } else {
            sessionSubtitle.text = "\(Int((seconds / 60).rounded(.up))) \(NSLocalizedString("#minutesRemaining#", comment: ""))"
        }
    }
    
    @objc func didClickButton() {
        homeView?.homeViewCell(self, didClickButtonForSession: session)
    }
}
