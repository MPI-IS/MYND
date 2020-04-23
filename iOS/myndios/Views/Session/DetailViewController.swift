//
//  DetailViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 24.11.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit

/// This view presents details of the current scenario. See documentation for more details.
class DetailViewController: UIViewController {
    
    @IBOutlet weak var sessionBackground: UIImageView!
    @IBOutlet weak var sessionDescriptionLabel: UITextView!
    @IBOutlet weak var sessionTitleLabel: UILabel!
    @IBOutlet weak var sessionIcon: ScenarioBubble!
    
    private let nc = NotificationCenter.default
    
    weak var sessionVC: MNDSessionVCBase?
    
    var completion: (()->())?

    static func make(_ sessionVC: MNDSessionVCBase, completion: (()->())? = nil) -> DetailViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DetailView") as! DetailViewController
        viewController.sessionVC = sessionVC
        viewController.completion = completion
        return viewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let session = sessionVC?.session else {return}

        sessionIcon.setScenario(session)
        sessionDescriptionLabel.text = "\(session.text.withFilledPlaceholders()) \(String(format: NSLocalizedString("#blockDuration#", comment: ""), Int((session.getDuration().block / 60).rounded(.up))))"
        sessionTitleLabel.text = session.title
        
        sessionBackground.image = session.image
        sessionBackground.contentMode = .scaleAspectFill
        sessionBackground.layer.masksToBounds = true
        sessionBackground.clipsToBounds = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        TTSController.shared.say(sessionDescriptionLabel.text!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        TTSController.shared.stop()
    }
    
    @IBAction func getStarted(_ sender: Any) {
        completion?()
    }
}

