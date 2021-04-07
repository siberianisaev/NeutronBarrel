//
//  CalculationsController.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 07.04.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Cocoa

class CalculationsController: NSWindowController {
    
    @IBInspectable dynamic var sTimePeakCenter: String = "" {
        didSet {
            updateHalfLife()
        }
    }
    @IBInspectable dynamic var sTimePeakCenterError: String = "" {
        didSet {
            updateHalfLife()
        }
    }
    
    @IBOutlet weak var textFieldHalfLife: NSTextField!
    
    fileprivate func updateHalfLife() {
        let xc = max(Float(sTimePeakCenter) ?? 0, 0)
        let xcError = max(Float(sTimePeakCenterError) ?? 0, 0)
        let tau = pow(10, xc)
        let positiveError = pow(10, xc + xcError) - tau
        let negativeError = tau - pow(10, xc - xcError)
        textFieldHalfLife.stringValue = "\(tau)\n+\(positiveError)\n-\(negativeError)"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        textFieldHalfLife.usesSingleLineMode = false
    }
    
}
