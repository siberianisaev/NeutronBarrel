//
//  CascadeController.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.04.2020.
//  Copyright © 2020 Flerov Laboratory. All rights reserved.
//

import Cocoa

class CascadeController: NSWindowController {
    
    @IBOutlet weak var particle3FrontControl: NSSegmentedControl!
    @IBOutlet weak var particle3BackControl: NSSegmentedControl!
    @IBOutlet weak var fissionAlpha3FormView: NSView!
    @IBOutlet weak var fissionAlpha3Button: NSButton!
    @IBOutlet weak var fissionAlpha3BackEnergyView: NSView!
    
    @IBInspectable var searchFissionBack3ByFact: Bool = Settings.getBoolSetting(.SearchFissionBack2ByFact) {
        didSet {
            setupFissionAlpha3BackEnergyView()
            Settings.setObject(searchFissionBack3ByFact, forSetting: .SearchFissionBack2ByFact)
        }
    }
    
    @IBInspectable var sMinFissionAlpha3Energy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha3Energy)) {
           didSet {
               Settings.setObject(Double(sMinFissionAlpha3Energy), forSetting: .MinFissionAlpha3Energy)
           }
       }
    
    @IBInspectable var sMaxFissionAlpha3Energy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha3Energy)) {
           didSet {
               Settings.setObject(Double(sMaxFissionAlpha3Energy), forSetting: .MaxFissionAlpha3Energy)
           }
       }
    
    @IBInspectable var sMinFissionAlpha3BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MinFissionAlpha3BackEnergy)) {
           didSet {
               Settings.setObject(Double(sMinFissionAlpha3BackEnergy), forSetting: .MinFissionAlpha3BackEnergy)
           }
       }
    
    @IBInspectable var sMaxFissionAlpha3BackEnergy = String(format: "%.1f", Settings.getDoubleSetting(.MaxFissionAlpha3BackEnergy)) {
        didSet {
            Settings.setObject(Double(sMaxFissionAlpha3BackEnergy), forSetting: .MaxFissionAlpha3BackEnergy)
        }
    }
    
    @IBInspectable var sMinFissionAlpha3Time = String(format: "%d", Settings.getIntSetting(.MinFissionAlpha3Time)) {
           didSet {
               Settings.setObject(Int(sMinFissionAlpha3Time), forSetting: .MinFissionAlpha3Time)
           }
       }
    @IBInspectable var sMaxFissionAlpha3Time = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha3Time)) {
           didSet {
               Settings.setObject(Int(sMaxFissionAlpha3Time), forSetting: .MaxFissionAlpha3Time)
           }
       }
    
    @IBInspectable var sMaxFissionAlpha3FrontDeltaStrips = String(format: "%d", Settings.getIntSetting(.MaxFissionAlpha3FrontDeltaStrips)) {
        didSet {
            Settings.setObject(Int(sMaxFissionAlpha3FrontDeltaStrips), forSetting: .MaxFissionAlpha3FrontDeltaStrips)
        }
    }
    
    @IBInspectable var summarizeFissionsFront3: Bool = Settings.getBoolSetting(.SummarizeFissionsFront3) {
        didSet {
            Settings.setObject(summarizeFissionsFront3, forSetting: .SummarizeFissionsFront3)
        }
    }
    
    @IBInspectable var searchFissionAlpha3: Bool = Settings.getBoolSetting(.SearchFissionAlpha3) {
        didSet {
            setupAlpha3FormView()
            Settings.setObject(searchFissionAlpha3, forSetting: .SearchFissionAlpha3)
        }
    }
    
    fileprivate func setupAlpha3FormView() {
        fissionAlpha3FormView.isHidden = !searchFissionAlpha3
        fissionAlpha3FormView.wantsLayer = true
        fissionAlpha3FormView.layer?.backgroundColor = NSColor.lightGray.cgColor
    }
    
    fileprivate func setupFissionAlpha3BackEnergyView() {
        fissionAlpha3BackEnergyView.isHidden = searchFissionBack3ByFact
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        setupAlpha3FormView()
        setupFissionAlpha3BackEnergyView()
        particle3FrontControl.selectedSegment = Settings.getIntSetting(.Particle3FrontSearchType)
        particle3BackControl.selectedSegment = Settings.getIntSetting(.Particle3BackSearchType)
    }
    
}
