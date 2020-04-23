//
//  NotificationViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 24.11.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import AVFoundation

/// Types of information that the notification VC can display, mostly control color
enum NotificationType {
    case info
    case error
    case success
}

/*
 Controller that shows a notification with a title, image, and message. Can be used for multiple purposes. This is essentially an error message. This view is almost identical to `Stepview` but can be called and presented any time during the EEG recording procedure if the battery is low or the headset disconnected. Color schemes for `error`, `success` and `info` are implemented.
 **/
class NotificationViewController: UIViewController {
    
    weak var sessionVC: SessionViewController?
    
    @IBOutlet weak var visualInstructionView: MNDVisualInstructionView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UITextView!
    @IBOutlet weak var doneButton: UIButton!
    
    var infoType = NotificationType.info
    var completion: (()->())?
    
    private let nc = NotificationCenter.default
    
    ////
    // Factory
    ////
    
    static func make(_ sessionVC: SessionViewController?, type: NotificationType, completion: (()->())? = nil) -> NotificationViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "NotificationView") as! NotificationViewController
        viewController.sessionVC = sessionVC
        viewController.infoType = type
        viewController.completion = completion
        return viewController
    }
    
    /// remove left bar button item, check wich message to display
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        setType(infoType)
        setMessage()
    }
    
    fileprivate func setType(_ infoType: NotificationType) {
        var color = UIColor.MP_Blue
        switch infoType {
        case .info :
            color = UIColor.MP_Blue
        case .success:
            color = UIColor.MP_Green
        case .error:
            color = UIColor.MP_Red
        }
        doneButton.backgroundColor = color
        titleLabel.textColor = color
    }
    
    func setMessage() {
        // check which type of error occured
        if infoType == .error && sessionVC != nil {
            if sessionVC!.dataController.deviceState[.batteryLow]! {
                visualInstructionView.set(visualInstructionString: "charge.mp4")
                titleLabel.text = NSLocalizedString("#batteryLowTitle#", comment: "")
                descriptionLabel.text = NSLocalizedString("#batteryLowText#", comment: "")
            } else if sessionVC!.dataController.deviceState[.disconnected]! {
                visualInstructionView.set(visualInstructionString: "error.jpeg")
                titleLabel.text = NSLocalizedString("#headsetDisconnected_Title#", comment: "")
                descriptionLabel.text = NSLocalizedString("#headsetDisconnected_Message#", comment: "")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        TTSController.shared.say(descriptionLabel.text!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        visualInstructionView.clear()
        TTSController.shared.stop()
    }
    
    @IBAction func gotIt(_ sender: Any) {
        completion?()
    }
}
