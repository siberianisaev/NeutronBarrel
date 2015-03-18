//
//  AppDelegate.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 08.01.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, ProcessorDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var activity: NSProgressIndicator!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    var sMinFissionEnergy: NSString = NSString(format: "%d", 20) // MeV
    var sMaxFissionEnergy: NSString = NSString(format: "%d", 200) // MeV
    var sMinRecoilEnergy: NSString = NSString(format: "%d", 1) // MeV
    var sMaxRecoilEnergy: NSString = NSString(format: "%d", 20) // MeV
    var sMinTOFChannel: NSString = NSString(format: "%d", 0) // channel
    var sMinRecoilTime: NSString = NSString(format: "%d", 0) // mks
    var sMaxRecoilTime: NSString = NSString(format: "%d", 1000) // mks
    var sMaxRecoilBackTime: NSString = NSString(format: "%d", 5) // mks
    var sMaxFissionTime: NSString = NSString(format: "%d", 5) // mks
    var sMaxTOFTime: NSString = NSString(format: "%d", 4) // mks
    var sMaxGammaTime: NSString = NSString(format: "%d", 5) // mks
    var sMaxNeutronTime: NSString = NSString(format: "%d", 132) // mks
    var sMaxRecoilFrontDeltaStrips: NSString = NSString(format: "%d", 0)
    var sMaxRecoilBackDeltaStrips: NSString = NSString(format: "%d", 0)
    var summarizeFissionsFront: Bool = false
    var requiredFissionBack: Bool = false
    var requiredRecoil: Bool = false
    var requiredGamma: Bool = false
    var requiredTOF: Bool = false
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
//TODO: добавить возможность остановить поиск
    @IBAction func start(sender: AnyObject?) {
        activity?.startAnimation(self)
        progressIndicator?.startAnimation(self)
        
        let processor = ISAProcessor.sharedProcessor();
        processor.fissionFrontMinEnergy = sMinFissionEnergy.doubleValue
        processor.fissionFrontMaxEnergy = sMaxFissionEnergy.doubleValue
        processor.recoilFrontMinEnergy = sMinRecoilEnergy.doubleValue
        processor.recoilFrontMaxEnergy = sMaxRecoilEnergy.doubleValue
        processor.minTOFChannel = sMinTOFChannel.doubleValue
        processor.recoilMinTime = sMinRecoilTime.doubleValue
        processor.recoilMaxTime = sMaxRecoilTime.doubleValue
        processor.recoilBackMaxTime = sMaxRecoilBackTime.doubleValue
        processor.fissionMaxTime = sMaxFissionTime.doubleValue
        processor.maxTOFTime = sMaxTOFTime.doubleValue
        processor.maxGammaTime = sMaxGammaTime.doubleValue
        processor.maxNeutronTime = sMaxNeutronTime.doubleValue
        processor.recoilFrontMaxDeltaStrips = sMaxRecoilFrontDeltaStrips.intValue
        processor.recoilBackMaxDeltaStrips = sMaxRecoilBackDeltaStrips.intValue
        processor.summarizeFissionsFront = summarizeFissionsFront
        processor.requiredFissionBack = requiredFissionBack
        processor.requiredRecoil = requiredRecoil
        processor.requiredGamma = requiredGamma
        processor.requiredTOF = requiredTOF
        processor.delegate = self
        processor.processDataWithCompletion({ [unowned self] in
            println("Done!")
            self.activity?.stopAnimation(self)
            self.progressIndicator?.doubleValue = 0.0
            self.progressIndicator?.stopAnimation(self)
        })
    }
    
    @IBAction func selectData(sender: AnyObject?) {
        ISAProcessor.sharedProcessor().selectData()
    }
    
    @IBAction func selectCalibration(sender: AnyObject?) {
        ISAProcessor.sharedProcessor().selectCalibration()
    }
    
    // MARK: - ProcessorDelegate
    
    func incrementProgress(delta: Double) {
        progressIndicator?.incrementBy(delta)
    }
    
}
