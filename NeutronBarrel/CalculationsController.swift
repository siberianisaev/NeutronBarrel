//
//  CalculationsController.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 07.04.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Cocoa

class CalculationsController: NSWindowController {
    
    // MARK: Half Life
    
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
    
    // MARK: Beam
    
    @IBInspectable dynamic var sBeamIonCharge: String = "" {
        didSet {
            updateIntegral()
            updateIntensity()
        }
    }
    
    @IBInspectable dynamic var sIntegral: String = "" {
        didSet {
            updateIntegral()
        }
    }
    
    @IBInspectable dynamic var sIntensity: String = "" {
        didSet {
            updateIntensity()
        }
    }
    
    @IBOutlet weak var textIntegral: NSTextField!
    
    fileprivate func updateIntegral() {
        // From microcoulombs to particles
        let particles = (pow(10, 13) * max(Float(sIntegral) ?? 0, 0))/(max(Float(sBeamIonCharge) ?? 1, 1) * 1.602176634) // 1E-6 / 1E-19
        textIntegral.stringValue = "\(particles) particles"
    }
    
    @IBOutlet weak var textIntensity: NSTextField!
    
    fileprivate func updateIntensity() {
        // From microampere to particles per seconds
        let pps = (6.25*pow(10, 12) * max(Float(sIntensity) ?? 0, 0))/(max(Float(sBeamIonCharge) ?? 1, 1))
        textIntensity.stringValue = "\(pps) particles/seconds"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        for tf in [textFieldHalfLife, textIntegral, textIntensity] {
            tf?.usesSingleLineMode = false
        }
    }
    
}
