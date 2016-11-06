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
    fileprivate var totalTime: TimeInterval = 0
    fileprivate var timer: Timer?
    var sMinFissionEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MinFissionEnergy)) // MeV
    var sMaxFissionEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MaxFissionEnergy)) // MeV
    var sMinRecoilEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MinRecoilEnergy)) // MeV
    var sMaxRecoilEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilEnergy)) // MeV
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
    var searchNeutrons: Bool = Settings.getBoolSetting(.SearchNeutrons)
    @IBOutlet weak var fissionAlphaControl: NSSegmentedControl!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        fissionAlphaControl.selectedSegment = Settings.getIntSetting(.SearchType)
        showAppVersion()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        saveSettings()
    }
    
//TODO: добавить возможность остановить поиск
    @IBAction func start(_ sender: AnyObject?) {
        activity?.startAnimation(self)
        progressIndicator?.startAnimation(self)
        fissionAlphaControl?.isEnabled = false
        startTimer()
        saveSettings()
        
        let processor = ISAProcessor.shared();
        
        processor?.startParticleType = fissionAlphaControl.selectedSegment == 0 ? .fission : .alpha
        processor?.fissionAlphaFrontMinEnergy = sMinFissionEnergy.doubleValue
        processor?.fissionAlphaFrontMaxEnergy = sMaxFissionEnergy.doubleValue
        processor?.fissionAlphaMaxTime = sMaxFissionTime.doubleValue
        processor?.summarizeFissionsAlphaFront = summarizeFissionsFront
        
        processor?.recoilFrontMaxDeltaStrips = sMaxRecoilFrontDeltaStrips.intValue
        processor?.recoilBackMaxDeltaStrips = sMaxRecoilBackDeltaStrips.intValue
        processor?.requiredFissionRecoilBack = requiredFissionRecoilBack
        processor?.requiredRecoil = requiredRecoil
        processor?.recoilFrontMinEnergy = sMinRecoilEnergy.doubleValue
        processor?.recoilFrontMaxEnergy = sMaxRecoilEnergy.doubleValue
        processor?.recoilMinTime = sMinRecoilTime.doubleValue
        processor?.recoilMaxTime = sMaxRecoilTime.doubleValue
        processor?.recoilBackMaxTime = sMaxRecoilBackTime.doubleValue
        
        processor?.minTOFChannel = sMinTOFChannel.doubleValue
        processor?.maxTOFTime = sMaxTOFTime.doubleValue
        processor?.requiredTOF = requiredTOF
        
        processor?.maxGammaTime = sMaxGammaTime.doubleValue
        processor?.requiredGamma = requiredGamma
        
        processor?.searchNeutrons = searchNeutrons
        processor?.maxNeutronTime = sMaxNeutronTime.doubleValue
        
        processor?.delegate = self
        processor?.processData(completion: { [unowned self] in
            self.activity?.stopAnimation(self)
            self.progressIndicator?.doubleValue = 0.0
            self.progressIndicator?.stopAnimation(self)
            self.stopTimer()
        })
    }
    
    @IBAction func selectData(_ sender: AnyObject?) {
        ISAProcessor.shared().selectData()
    }
    
    @IBAction func selectCalibration(_ sender: AnyObject?) {
        ISAProcessor.shared().selectCalibration()
    }
    
    // MARK: - ProcessorDelegate
    
    func incrementProgress(_ delta: Double) {
        progressIndicator?.increment(by: delta)
    }
    
    func startProcessingFile(_ fileName: String) {
        labelProcessingFileName?.stringValue = fileName
    }
    
    // MARK: - Timer
    
    fileprivate func startTimer() {
        totalTime = 0
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(AppDelegate.incrementTotalTime), userInfo: nil, repeats: true)
        labelTotalTime?.stringValue = ""
        labelTotalTime?.isHidden = false
        labelProcessingFileName?.stringValue = ""
        labelProcessingFileName?.isHidden = false
    }
    
    fileprivate func stringTotalTime() -> String {
        let seconds = Int(totalTime.truncatingRemainder(dividingBy: 60))
        let minutes = Int((totalTime / 60).truncatingRemainder(dividingBy: 60))
        let hours = Int(totalTime / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func incrementTotalTime() {
        totalTime += 1
        labelTotalTime?.stringValue = stringTotalTime()
    }
    
    fileprivate func stopTimer() {
        timer?.invalidate()
        labelProcessingFileName?.isHidden = true
    }
    
    // MARK: - Settings
    
    fileprivate func saveSettings() {
        Settings.setObject(sMinFissionEnergy.doubleValue, forSetting: .MinFissionEnergy)
        Settings.setObject(sMaxFissionEnergy.doubleValue, forSetting: .MaxFissionEnergy)
        Settings.setObject(sMinRecoilEnergy.doubleValue, forSetting: .MinRecoilEnergy)
        Settings.setObject(sMaxRecoilEnergy.doubleValue, forSetting: .MaxRecoilEnergy)
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
        Settings.setObject(fissionAlphaControl.selectedSegment, forSetting: .SearchType)
    }
    
    // MARK: - App Version
    
    fileprivate func infoPlistStringForKey(_ key: String) -> String? {
        return Bundle.main.infoDictionary![key] as? String
    }
    
    fileprivate func showAppVersion() {
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
