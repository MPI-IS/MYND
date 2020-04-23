//
//  HomeViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 14.08.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit
import BLTNBoard

protocol DayTimeOutListener: class {
    func study(_ study: StudyModel, didChangeTimeOutStateTo state: DayTimeOutState)
}

/*
 This controller is responsible for the main view of the application. The home view is essentially a table with a timer. Upon loading, it retrieves scenarios for the current study day, the completed scenarios of the current study day, the remaining time to complete those scenarios, and any announcement on the download webdav. Further, if all scenarios were completed, it immediately instantiates the `WaitView`, and advances the study to the next day if the waiting time passed (`DayTimeOutListener` extension). 
 **/
class HomeViewController: UITableViewController {
    
    /// Factory
    static func make(_ mainVC: MainViewController) -> HomeViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HomeView") as! HomeViewController
        viewController.mainVC = mainVC
        return viewController
    }
    
    var footerView: UIView?
    var timeRemainingLabel: UILabel?
    
    let defaults = UserDefaults.standard
    let nc = NotificationCenter.default
    weak var mainVC: MainViewController! = nil
    var cells = [HomeViewCell]()
    
    var dayTimeOutChecker: Timer?
    
    var study: StudyModel! = nil
    
    // this is used for announcement pop overs
    lazy var bulletinManager: BLTNItemManager = {
        let rootItem: BLTNItem = BLTNPageItem()
        return BLTNItemManager(rootItem: rootItem)
    }()
    
    // this will be set once all scenarios and progress is loaded
    private var activeRow: Int = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // set study
        study = StudyController.shared.currentStudy!
        
        // set table view specifics
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        
        // create the footer view for remaining minutes of time out
        footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 40))
        let label = UILabel(frame: footerView!.bounds)
        footerView!.backgroundColor = UIColor.groupTableViewBackground
        timeRemainingLabel = label
        label.textColor = Constants.appTint
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        footerView!.addSubview(label)
        footerView!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(timeOutDay(_:))))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("#settings#", comment: ""), style: .plain, target: self, action: #selector(showSettings))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("#help#", comment: ""), style: .plain, target: self, action: #selector(showHelp))
        
        // load all scenarios that should be displayed
        createCells()
        setDayTimeOutChecker()
        
        // check for remote messages if any
        TransferController.shared.checkForMessage()
        nc.addObserver(self, selector: #selector(updateProgress), name: Notification.Name("didReceiveRemoteMessage"), object: nil)
    }
    
    /// this checks every minute if the waiting time passed, useful if subjects just leave the app running
    func setDayTimeOutChecker() {
        dayTimeOutChecker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.checkTimeOut()
            }
    }
    
    private func checkTimeOut() {
        let timeOutState = study.checkForDayTimeOut()
        switch timeOutState.state {
        case .none:
            timeRemainingLabel?.text = nil
            dayTimeOutChecker?.invalidate()
        case .wait:
            timeRemainingLabel?.text = "\(NSLocalizedString("#nextDayIn#", comment: "")) \(timeOutState.timeInterval.stringFromTimeInterval())"
        case .timeOut:
            study(self.study, didChangeTimeOutStateTo: .timeOut)
            dayTimeOutChecker?.invalidate()
        }
    }
    
    private func createCells() {
        print("creating cells for day \(study.currentDay)")
        var cells = [HomeViewCell]()
        for (c,scenario) in study.getDay().enumerated() {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "homeViewCell", for: IndexPath(row: c, section: 0)) as? HomeViewCell else {break}
            cell.setSession(scenario)
            cell.homeView = self
            //cell.activeHeight = UIScreen.main.bounds.height * 0.35
            //cell.inactiveHeight = UIScreen.main.bounds.height * 0.2
            cell.sessionIcon.homeViewCell = cell
            cell.setActive(false)
            cells.append(cell)
        }
        self.cells = cells
        tableView.reloadData()
        updateProgress()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dayTimeOutChecker?.invalidate()
        dayTimeOutChecker = nil
        nc.removeObserver(self)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
        
    /// this function takes the current study progress and applies it to scenarios of the current day
    @objc func updateProgress() {
        checkTimeOut() // check for correct display
        checkDayOrStudyCompletion()
        
        guard let activeSessionIndex = study.getSession()?.index else {return}
        var activeRow = 0
        for (c,cell) in cells.enumerated() {
            // set current session to active
            if cell.session.index == activeSessionIndex {
                activeRow = c
                cell.setActive()
            } else {
                cell.setActive(false)
            }
            // update minutes remaining
            cell.setRemainingMinutes()
            // update icon
            cell.sessionIcon.updateProgress()
        }

        // if the active row changed, perform a scroll animation and store the new value
        if activeRow != self.activeRow {
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.scrollToRow(at: IndexPath(row: activeRow, section: 0), at: .top, animated: true)
            self.activeRow = activeRow
        }
        
    }
    
    // if the day was completed and we are in timeOut, show the wait screen and return
    func checkDayOrStudyCompletion() {
        let completion = study.checkCompletion()
        if completion.day {
            var reason = WaitReason.didFinishDay
            // if the whole study was completed, just immediately timeOut
            if completion.study {
                reason = WaitReason.didFinishStudy
                //study(study, didChangeTimeOutStateTo: .timeOut)
            }
            let vc = WaitViewController.make(reason: reason)
            vc.dayTimeOutListener = self
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
            return
        }
    }
    
    @objc func showSettings() {
        let vc = SettingsViewController.make(mainVC)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func showHelp() {
        let vc = HelpTableViewController.make()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // return the scenario cell from array
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
    
    // the current scenario is expanded
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            if indexPath.row == study.getSession()!.index {
                return UIScreen.main.bounds.height * 0.35 //Expanded
            }
            return UIScreen.main.bounds.height * 0.2  //Not expanded
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // row and section count
    override func numberOfSections(in tableView: UITableView) -> Int {
            return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    // footer is visible if a timer is running
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if study.checkForDayTimeOut().state == .none {
            return nil
        } else {
            return footerView
        }
    }
    
    // this is for manually timing out the day in dev mode
    @objc func timeOutDay(_ sender: UITapGestureRecognizer) {
        guard defaults.bool(forKey: "isDeveloperModeEnabled") else {return}
        print("Developer timed out the day")
        study(study, didChangeTimeOutStateTo: .timeOut)
    }
    
    // this is for correct display of the footer
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if study.checkForDayTimeOut().state == .none {
            return 0
        } else {
            return 40
        }
    }
    
}

///`HomeViewController` also executes actions after the subject taps on the "Start session" button in a `HomeViewCell`, either by showing a new announcement or by instantiating an EEG recording or questionnaire session (`HomeViewCellDelegate` extension).
extension HomeViewController: HomeViewCellDelegate {
    
    // Clicked button to start recording
    func homeViewCell(_ homeViewCell: HomeViewCell?, didClickButtonForSession session: ScenarioModel) {
        
        // Show a new announcement if any
        if let message = BannerController.shared.getRemoteMessageIfAny() {
            
            let item = BLTNPageItem(title: message.title)
            item.descriptionText = message.text
            item.actionButtonTitle = NSLocalizedString("#getStarted#", comment: "")
            item.actionButton?.tintColor = Constants.appTint
            item.actionHandler = {[weak self] bulletin in
                self?.defaults.set(false, forKey: "shouldPresentRemoteMessage"); self?.homeViewCell(homeViewCell, didClickButtonForSession: session); bulletin.manager?.dismissBulletin()}
            item.alternativeButtonTitle = NSLocalizedString("#cancel#", comment: "")
            item.alternativeHandler = {bulletin in TTSController.shared.stop(); bulletin.manager?.dismissBulletin()}
            item.alternativeButton?.tintColor = Constants.appTint
            
            bulletinManager = BLTNItemManager(rootItem: item)
            bulletinManager.showBulletin(above: self, animated: true, completion: {TTSController.shared.say(message.text)})
            return
        }
        
        // else start the correct session
        switch session.type {
        case .recording:
            let vc = SessionViewController.make(session: session)
            mainVC.nav.pushViewController(vc, animated: true)
        case .questionnaire:
            let vc = QuestionViewController.make(session: session)
            mainVC.nav.pushViewController(vc, animated: true)
        }
    }
    
    // Session was set active, will only happen in dev mode
    func homeViewCell(_ homeViewCell: HomeViewCell?, setActiveForSession session: ScenarioModel) {
        study.setSessionIndex(to: session.index)
    }
    
    // Session progress was updated, will only happen in dev mode
    func homeViewCell(_ homeViewCell: HomeViewCell?, didUpdateProgressForSession session: ScenarioModel) {
        session.scenarioCompleted ? (_ = study.advanceSession()) : ()
        _ = study.checkCompletion()
        StudyController.shared.saveCurrentStudyProgress()
        updateProgress()
    }
}

extension HomeViewController: DayTimeOutListener {
    /// advances the study to the next day if the waiting time passed
    func study(_ study: StudyModel, didChangeTimeOutStateTo state: DayTimeOutState) {
        switch state {
        case .timeOut:
            print("advancing day after timeOut")
            // cancel any remaining user notifications
            BannerController.shared.cancelUserNotificationForDay()
            study.completeDay()
            checkDayOrStudyCompletion()
            study.advanceDay()
            createCells()
            StudyController.shared.saveCurrentStudyProgress()
        default:
            break
        }
    }
}
