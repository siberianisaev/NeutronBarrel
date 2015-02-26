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
    var sMinEnergy: NSString = NSString(format: "%d", 20) // MeV
    var sMinTOFChannel: NSString = NSString(format: "%d", 0) // channel
    var sMinRecoilTime: NSString = NSString(format: "%d", 0) // mks
    var sMaxRecoilTime: NSString = NSString(format: "%d", 1000) // mks
    var sMaxFissionTime: NSString = NSString(format: "%d", 5) // mks
    var requiredFissionBack: Bool = true
    var requiredGamma: Bool = true
    var requiredTOF: Bool = false
    
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
        processor.minTOFChannel = sMinTOFChannel.doubleValue
        processor.recoilMinTime = sMinRecoilTime.doubleValue
        processor.recoilMaxTime = sMaxRecoilTime.doubleValue
        processor.fissionMaxTime = sMaxFissionTime.doubleValue
        processor.requiredFissionBack = requiredFissionBack
        processor.requiredGamma = requiredGamma
        processor.requiredTOF = requiredTOF
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
