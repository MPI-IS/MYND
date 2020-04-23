//
//  StepModel.swift
//  myndios
//
//  Created by Matthias Hohmann on 21.06.18.
//  Copyright © 2018 Matthias Hohmann. All rights reserved.
//

import UIKit

/**
 Note: The functions that are attached to this enum are defined whereever they are invoked, this is merely a list of options. At the time of creation, this was only used to enable or disable certain electrodes during the fitting procedure. Find them in `FittingViewController -> completionIfAny()`.
 */
enum CompletionFunction: String {
    case activateFront
    case activateBack
    case deactivateAll
    case activateAll
    case success
}

/**
 Hardware preparation steps can be *regular* or *short*, which was implemented to progress faster through preparation after having done it several times. Videos or images can be presented alongside a preparation step. Optionally, a step can be locked until it receives a `CompletionSignal` from the device, and a `CompletionFunction` can be executed as well after a step was completed. Steps can also have a time out, to prevent users from getting stuck.
 */
class StepModel: NSObject {
    
    let name: String
    let pictureName: String?
    var instruction: String
    
    let buttonTitle: String?
    let buttonSuccessTitle: String?
    let timeOut: Double?
    let completionSignal: DeviceStates?
    let completion: CompletionFunction?
    var success: Bool
    
    
    init(_ name: String, _ pictureName: String? = nil, _ instruction: String, _ buttonTitle: String? = nil, _ buttonSuccessTitle: String? = nil, _ timeOut: Double? = nil, _ completionSignal: DeviceStates? = nil, _ completion: CompletionFunction? = nil) {
        self.name = name
        self.pictureName = pictureName
        self.instruction = instruction
        
        self.buttonTitle = buttonTitle
        self.buttonSuccessTitle = buttonSuccessTitle
        self.timeOut = timeOut
        
        self.completionSignal = completionSignal
        (self.completionSignal != nil) ? (self.success = false) : (self.success = true)
        self.completion = completion
    }
}
