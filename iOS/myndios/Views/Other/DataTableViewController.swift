//
//  DataTableViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 21.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit

class DataCell: UITableViewCell {
    @IBOutlet weak var type: UILabel!
    @IBOutlet weak var date: UILabel!
    var item: DataModel!
}

/// this view exists in Settings, it presents existing recordings on the device. With developer-mode enabled, you can share and delete those recordings.
class DataTableViewController: UITableViewController {
    
    let defaults: UserDefaults = UserDefaults.standard
    var storedData: [DataModel] = [DataModel]()
    weak var mainVC: MainViewController! = nil
    
    ////
    // Factory
    ////
    
    static func make(_ mainVC: MainViewController) -> DataTableViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RecordedData") as! DataTableViewController
        viewController.mainVC = mainVC
        return viewController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
     // Fetch all existing files
        storedData = [DataModel]()
        for item in defaults.array(forKey: "storedData") as! [Dictionary<String, Any>] {
            storedData.append(DataModel.init(withDict: item))
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataCell", for: indexPath) as! DataCell
        cell.item = storedData[indexPath.row]
        cell.type.text = "\(cell.item.type)".capitalized
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.autoupdatingCurrent
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyy-MM-dd 'at' HH:mm")
        cell.date.text = dateFormatter.string(from: cell.item.date)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        if defaults.bool(forKey: "isDeveloperModeEnabled") {
        let shareAction = UIContextualAction(style: .destructive, title: "Share") { (action, view, handler) in
            self.shareFileAtIndex(indexPath)
        }
        shareAction.backgroundColor = UIColor.MP_Blue
        let configuration = UISwipeActionsConfiguration(actions: [shareAction])
        return configuration
        } else {
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if defaults.bool(forKey: "isDeveloperModeEnabled") {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") {  (action, view, handler) in
            self.deleteFileAtIndex(indexPath)
        }
        deleteAction.backgroundColor = UIColor.red
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        return configuration
        } else {
            return nil
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storedData.count
    }
    
    /// this function allows for deletion of individual files on the device. only available in developer-mode.
    fileprivate func deleteFileAtIndex(_ indexPath: IndexPath) {
        let fileManager = FileManager.default
        //let dir = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first)?.appendingPathComponent(storedData[indexPath.row].fileName)
        let dir = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(storedData[indexPath.row].fileName))!
        do {
            try fileManager.removeItem(at: dir)
            print("Removed file")
            storedData.remove(at: indexPath.row)
            defaults.set(storedData.map{$0.asDictionary()}, forKey: "storedData")
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        catch {
            print("Could not remove file at \(storedData[indexPath.row].fileName)")
        }
    
        // Double check file count
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            print(fileURLs)
        } catch {
            print("Error while enumerating files: \(error.localizedDescription)")
        }
    }
    
    /// this function allows to manually copy files off the device via activityview. Only available in developer mode
    fileprivate func shareFileAtIndex(_ indexPath: IndexPath) {
        let dir = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(storedData[indexPath.row].fileName))!
        let vc = UIActivityViewController(activityItems: [dir], applicationActivities: nil)
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.sourceView = self.tableView.cellForRow(at: indexPath)?.contentView
        
        vc.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .postToTwitter,
            .postToFacebook,
            .openInIBooks
        ]
        self.present(vc, animated: true, completion: nil)
    }
    
}
