//
//  CreditsViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 01.10.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import MarkdownView

/// credits of the application, loaded from a markdown file
class CreditsViewController: UIViewController {
    
    @IBOutlet weak var creditsText: MarkdownView!
    
    static func make() -> CreditsViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "credits") as! CreditsViewController
        return viewController
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let mdFile = Bundle.main.url(forResource: "Credits", withExtension: "txt"),
                 let mdData = try? Data(contentsOf: mdFile),
                     let string = String(data: mdData, encoding: .utf8) {
            creditsText.load(markdown: string)
         }
    }
}
