//
//  HelpDetailViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 30.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import SwiftyJSON

/// see `HelpTableViewController` for more details
class HelpDetailViewController: UIViewController {
    
    /// Factory
    static func make(withJson json: JSON) -> HelpDetailViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HelpDetailView") as! HelpDetailViewController
        viewController.helpItem = json
        return viewController
    }
    
    @IBOutlet weak var visualInstructionView: MNDVisualInstructionView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UITextView!
    
    var helpItem: JSON?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let helpItem = helpItem,
            let title = helpItem["title"].string,
                let text = helpItem["text"].string else {return}
        
        // update visuals if any
        if let picture = helpItem["picture"].string {
            visualInstructionView.set(visualInstructionString: picture)
        } else {
            visualInstructionView.set(visualInstructionString: "help.jpeg")
        }
        
        // update text
        titleLabel.text = title
        descriptionLabel.text = text
    }
}
