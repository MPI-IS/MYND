//
//  HelpTableViewCell.swift
//  myndios
//
//  Created by Matthias Hohmann on 30.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import SwiftyJSON

/// see `HelpTableViewController` for more details
class HelpTableViewCell: UITableViewCell {
    
    @IBOutlet weak var helpView: MNDVisualInstructionView!
    @IBOutlet weak var helpLabel: UILabel!
    
    // This struct stores all the information about the help item
    var helpItem: JSON?
    
    func setHelpItem(json: JSON) {

        
        guard let title = json["title"].string,
            json["text"].string != nil else {return}
        
        // set current help item
        helpItem = json
        
        // update visuals if any
        if let picture = json["picture"].string {
            helpView.set(visualInstructionString: picture)
        } else {
            helpView.set(visualInstructionString: "help.jpeg")
        }
        
        // update label
        helpLabel.text = title
    }
}
