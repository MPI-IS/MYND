//
//  UploadViewController.swift
//  myndios
//
//  Created by Matthias Hohmann on 18.12.17.
//  Copyright © 2017 Matthias Hohmann. All rights reserved.
//

import UIKit
import UICircularProgressRing

/// A visual representation of the file upload progress. Implements `TransferControllerDelegate` to recieve progress updates
class UploadViewController: UIViewController, TransferControllerDelegate {
    
    @IBOutlet weak var uploadProgress: UICircularProgressRing!
    @IBOutlet weak var uploadImage: UIImageView!
    @IBOutlet weak var uploadTitle: UILabel!
    @IBOutlet weak var uploadText: UILabel!
    @IBOutlet weak var uploadButton: UIButton!
    
    weak var transferController: TransferController!
    var completion: (()->())?
    
    static func make(_ transferController: TransferController, completion: (()->())? = nil) -> UploadViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Upload") as! UploadViewController
        viewController.transferController = transferController
        viewController.completion = completion
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        uploadProgress.maxValue = 1
        uploadProgress.minValue = 0
        uploadProgress.showFloatingPoint = false
        uploadProgress.shouldShowValueText = false
        uploadProgress.outerRingColor = UIColor.MP_lightBlue
        uploadProgress.outerRingWidth = 5.0
        uploadProgress.innerRingColor = Constants.appTint
        uploadProgress.innerRingWidth = 8.0
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        uploadProgress.makeCircular()
        uploadImage.makeCircular()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        transferController.delegate = self
    }
    
    func transferController(_ transferController: TransferController, didUpdateProgressTo progress: Float) {
        DispatchQueue.main.async{self.uploadProgress.startProgress(to: UICircularProgressRing.ProgressValue(progress), duration: 0.3)}
    }
    
    func transferController(_ transferController: TransferController, didUpdateStateTo state: TransferStates, withMessage message: String) {
        DispatchQueue.main.async{
            self.uploadText.text = message
            TTSController.shared.say(message)
            switch state {
            case .started:
                self.uploadTitle.text = NSLocalizedString("#upload_Progress#", comment: "")
            case .error:
                self.uploadTitle.text = NSLocalizedString("#upload_Failed#", comment: "")
                self.uploadTitle.textColor = .MP_Red
                self.uploadProgress.outerRingColor = .MP_Red
                self.uploadProgress.innerRingColor = .MP_Red
                self.uploadButton.backgroundColor = .MP_Red
                self.uploadImage.image = #imageLiteral(resourceName: "Cloud_Fail")
            case .completed:
                self.uploadTitle.textColor = Constants.appTint
                self.uploadTitle.text = NSLocalizedString("#upload_Complete#", comment: "")
                self.uploadImage.image = #imageLiteral(resourceName: "Cloud_Done")
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        transferController.delegate = nil
    }
    
    @IBAction func gotIt() {
        completion?()
    }
}
