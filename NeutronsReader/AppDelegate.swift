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
    @IBOutlet weak var labelVersion: NSTextField!
    @IBOutlet weak var labelTotalTime: NSTextField!
    @IBOutlet weak var labelProcessingFileName: NSTextField!
    private var totalTime: NSTimeInterval = 0
    private var timer: NSTimer?
    var sMinFissionEnergy: NSString = NSString(format: "%d", Settings.getIntSetting(.MinFissionEnergy)) // MeV
    var sMaxFissionEnergy: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxFissionEnergy)) // MeV
    var sMinRecoilEnergy: NSString = NSString(format: "%d", Settings.getIntSetting(.MinRecoilEnergy)) // MeV
    var sMaxRecoilEnergy: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxRecoilEnergy)) // MeV
    var sMinTOFChannel: NSString = NSString(format: "%d", Settings.getIntSetting(.MinTOFChannel)) // channel
    var sMinRecoilTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MinRecoilTime)) // mks
    var sMaxRecoilTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxRecoilTime)) // mks
    var sMaxRecoilBackTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxRecoilBackTime)) // mks
    var sMaxFissionTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxFissionTime)) // mks
    var sMaxTOFTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxTOFTime)) // mks
    var sMaxGammaTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxGammaTime)) // mks
    var sMaxNeutronTime: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxNeutronTime)) // mks
    var sMaxRecoilFrontDeltaStrips: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxRecoilFrontDeltaStrips))
    var sMaxRecoilBackDeltaStrips: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxRecoilBackDeltaStrips))
    var summarizeFissionsFront: Bool = Settings.getBoolSetting(.SummarizeFissionsFront)
    var requiredFissionRecoilBack: Bool = Settings.getBoolSetting(.RequiredFissionRecoilBack)
    var requiredRecoil: Bool = Settings.getBoolSetting(.RequiredRecoil)
    var requiredGamma: Bool = Settings.getBoolSetting(.RequiredGamma)
    var requiredTOF: Bool = Settings.getBoolSetting(.RequiredTOF)
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        showAppVersion()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        saveSettings()
    }
    
//TODO: добавить возможность остановить поиск
    @IBAction func start(sender: AnyObject?) {
        activity?.startAnimation(self)
        progressIndicator?.startAnimation(self)
        startTimer()
        
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
        processor.requiredFissionRecoilBack = requiredFissionRecoilBack
        processor.requiredRecoil = requiredRecoil
        processor.requiredGamma = requiredGamma
        processor.requiredTOF = requiredTOF
        processor.delegate = self
        processor.processDataWithCompletion({ [unowned self] in
            self.activity?.stopAnimation(self)
            self.progressIndicator?.doubleValue = 0.0
            self.progressIndicator?.stopAnimation(self)
            self.stopTimer()
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
    
    func startProcessingFile(fileName: String) {
        labelProcessingFileName?.stringValue = fileName
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        totalTime = 0
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "incrementTotalTime", userInfo: nil, repeats: true)
        labelTotalTime?.stringValue = ""
        labelTotalTime?.hidden = false
        labelProcessingFileName?.stringValue = ""
        labelProcessingFileName?.hidden = false
    }
    
    private func stringTotalTime() -> String {
        let seconds = Int(totalTime % 60)
        let minutes = Int((totalTime / 60) % 60)
        let hours = Int(totalTime / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func incrementTotalTime() {
        totalTime++
        labelTotalTime?.stringValue = stringTotalTime()
    }
    
    private func stopTimer() {
        timer?.invalidate()
        labelProcessingFileName?.hidden = true
    }
    
    // MARK: - Settings
    
    private func saveSettings() {
        Settings.setObject(sMinFissionEnergy.integerValue, forSetting: .MinFissionEnergy)
        Settings.setObject(sMaxFissionEnergy.integerValue, forSetting: .MaxFissionEnergy)
        Settings.setObject(sMinRecoilEnergy.integerValue, forSetting: .MinRecoilEnergy)
        Settings.setObject(sMaxRecoilEnergy.integerValue, forSetting: .MaxRecoilEnergy)
        Settings.setObject(sMinTOFChannel.integerValue, forSetting: .MinTOFChannel)
        Settings.setObject(sMinRecoilTime.integerValue, forSetting: .MinRecoilTime)
        Settings.setObject(sMaxRecoilTime.integerValue, forSetting: .MaxRecoilTime)
        Settings.setObject(sMaxRecoilBackTime.integerValue, forSetting: .MaxRecoilBackTime)
        Settings.setObject(sMaxFissionTime.integerValue, forSetting: .MaxFissionTime)
        Settings.setObject(sMaxTOFTime.integerValue, forSetting: .MaxTOFTime)
        Settings.setObject(sMaxGammaTime.integerValue, forSetting: .MaxGammaTime)
        Settings.setObject(sMaxNeutronTime.integerValue, forSetting: .MaxNeutronTime)
        Settings.setObject(sMaxRecoilFrontDeltaStrips.integerValue, forSetting: .MaxRecoilFrontDeltaStrips)
        Settings.setObject(sMaxRecoilBackDeltaStrips.integerValue, forSetting: .MaxRecoilBackDeltaStrips)
        Settings.setObject(summarizeFissionsFront, forSetting: .SummarizeFissionsFront)
        Settings.setObject(requiredFissionRecoilBack, forSetting: .RequiredFissionRecoilBack)
        Settings.setObject(requiredRecoil, forSetting: .RequiredRecoil)
        Settings.setObject(requiredGamma, forSetting: .RequiredGamma)
        Settings.setObject(requiredTOF, forSetting: .RequiredTOF)
    }
    
    // MARK: - App Version
    
    private func infoPlistStringForKey(key: String) -> String? {
        return NSBundle.mainBundle().infoDictionary![key] as? String
    }
    
    private func showAppVersion() {
        var string = ""
        if let version = infoPlistStringForKey("CFBundleShortVersionString") {
            string += "Version " + version
        }
        if let build = infoPlistStringForKey("CFBundleVersion") {
            string += " (" + build + ")."
        }
        if let gitSHA = infoPlistStringForKey("CFBundleVersionGitSHA") {
            string += " Git SHA " + gitSHA
        }
        labelVersion?.stringValue = string
    }
    
}
