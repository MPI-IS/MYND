//
//  HelpTableViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 30.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import SwiftyJSON

/// The `HelpView` is a simple way to display frequently asked questions to all subjects. `HelpTableView` contains an overview of questions represented by `HelpTableViewCell`, and tapping leads to the `HelpDetailView`. Frequently asked questions are stored as JSON. Please refer to `help_en.json` for an example structure.
class HelpTableViewController: UITableViewController {
    
    /// Factory
    static func make() -> HelpTableViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HelpView") as! HelpTableViewController
        return viewController
    }
    
    var cells = [HelpTableViewCell]()
    
    /// assign delegate and data source of table view to self
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 180
        tableView.estimatedRowHeight = UITableView.automaticDimension
        
        createCells()
    }
    
    /// create cells with the help JSON returned from DocumentController
    private func createCells() {
        let locale = NSLocale.autoupdatingCurrent.languageCode
        
        // check if file exists and whether it has the right format
        guard let helpJSON = DocumentController.shared.returnJSON("help_\(locale ?? "en")"),
            let helpItems = helpJSON["items"].array else {return}
        
        for (c,item) in helpItems.enumerated() {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "helpTableViewCell", for: IndexPath(row: c, section: 0)) as? HelpTableViewCell else {break}
            cell.setHelpItem(json: item)
            cells.append(cell)
        }
    }
    
    /// display detail view
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = cells[indexPath.row]
        let vc = HelpDetailViewController.make(withJson: cell.helpItem!)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    /// large titles
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    // return the help cell from array
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
    
    // row and section count
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
}
