//
//  AppDelegate.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 08.01.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var activity: NSProgressIndicator!
    var sMinEnergy: NSString = NSString(format: "%d", 20) // Default focal fission min energy (MeV)
    var sMinRecoilTime: NSString = NSString(format: "%d", 0) // mks
    var sMaxRecoilTime: NSString = NSString(format: "%d", 1000) // mks
    var onlyWithFissionBack: Bool = false
    var onlyWithGamma: Bool = false
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    @IBAction func start(sender: AnyObject?) {
        activity?.startAnimation(self)
        let processor = ISAProcessor.sharedProcessor();
        processor.fissionFrontMinEnergy = sMinEnergy.doubleValue
        processor.recoilMinTime = sMinRecoilTime.doubleValue
        processor.recoilMaxTime = sMaxRecoilTime.doubleValue
        processor.onlyWithFissionBack = onlyWithFissionBack
        processor.onlyWithGamma = onlyWithGamma
        processor.processData()
        activity?.stopAnimation(self)
    }
    
    @IBAction func selectData(sender: AnyObject?) {
        ISAProcessor.sharedProcessor().selectData()
    }
    
    @IBAction func selectCalibration(sender: AnyObject?) {
        ISAProcessor.sharedProcessor().selectCalibration()
    }
    
}
