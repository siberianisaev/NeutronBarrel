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
    @IBOutlet weak var labelBranch: NSTextField!
    @IBOutlet weak var labelTotalTime: NSTextField!
    @IBOutlet weak var labelProcessingFileName: NSTextField!
    @IBOutlet weak var fissionAlphaControl: NSSegmentedControl!
    @IBOutlet weak var tofUnitsControl: NSSegmentedControl!
    @IBOutlet weak var indicatorData: NSTextField!
    @IBOutlet weak var indicatorCalibration: NSTextField!
    @IBOutlet weak var buttonRun: NSButton!
    
    fileprivate var totalTime: TimeInterval = 0
    fileprivate var timer: Timer?
    
    var sMinFissionEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MinFissionEnergy)) // MeV
    var sMaxFissionEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MaxFissionEnergy)) // MeV
    var sMinRecoilEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MinRecoilEnergy)) // MeV
    var sMaxRecoilEnergy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MaxRecoilEnergy)) // MeV
    var sMinTOFValue: NSString = NSString(format: "%d", Settings.getIntSetting(.MinTOFValue)) // channel or ns
    var sMaxTOFValue: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxTOFValue)) // channel or ns
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
    // Alpha 2
    var searchAlpha2: Bool = Settings.getBoolSetting(.SearchAlpha2)
    var sMinAlpha2Energy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MinAlpha2Energy)) // MeV
    var sMaxAlpha2Energy: NSString = NSString(format: "%.1f", Settings.getDoubleSetting(.MaxAlpha2Energy)) // MeV
    var sMinAlpha2Time: NSString = NSString(format: "%d", Settings.getIntSetting(.MinAlpha2Time)) // mks
    var sMaxAlpha2Time: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxAlpha2Time)) // mks
    var sMaxAlpha2FrontDeltaStrips: NSString = NSString(format: "%d", Settings.getIntSetting(.MaxAlpha2FrontDeltaStrips))
    var searchSpecialEvents: Bool = Settings.getBoolSetting(.SearchSpecialEvents)
    var specialEventIds: NSString = Settings.getStringSetting(.SpecialEventIds) ?? ""
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        fissionAlphaControl.selectedSegment = Settings.getIntSetting(.SearchType)
        tofUnitsControl.selectedSegment = Settings.getIntSetting(.TOFUnits)
        for i in [indicatorData, indicatorCalibration] {
            setSelected(false, indicator: i)
        }
        showAppVersion()
        run = false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        saveSettings()
    }
    
    fileprivate func setSelected(_ selected: Bool, indicator: NSTextField?) {
        indicator?.textColor = selected ? NSColor.green : NSColor.red
        indicator?.stringValue = selected ? "✓" : "×"
    }
    
    @IBAction func start(_ sender: AnyObject?) {
        let processor = Processor.singleton
        if run {
            processor.stop()
            run = false
        } else {
            run = true
            
            processor.startParticleType = fissionAlphaControl.selectedSegment == 0 ? .fission : .alpha
            processor.fissionAlphaFrontMinEnergy = sMinFissionEnergy.doubleValue
            processor.fissionAlphaFrontMaxEnergy = sMaxFissionEnergy.doubleValue
            processor.fissionAlphaMaxTime = UInt64(sMaxFissionTime.longLongValue)
            processor.summarizeFissionsAlphaFront = summarizeFissionsFront
            
            processor.searchAlpha2 = searchAlpha2
            processor.alpha2MinEnergy = sMinAlpha2Energy.doubleValue
            processor.alpha2MaxEnergy = sMaxAlpha2Energy.doubleValue
            processor.alpha2MinTime = UInt64(sMinAlpha2Time.doubleValue)
            processor.alpha2MaxTime = UInt64(sMaxAlpha2Time.doubleValue)
            processor.alpha2MaxDeltaStrips = sMaxAlpha2FrontDeltaStrips.integerValue
            
            processor.recoilFrontMaxDeltaStrips = sMaxRecoilFrontDeltaStrips.integerValue
            processor.recoilBackMaxDeltaStrips = sMaxRecoilBackDeltaStrips.integerValue
            processor.requiredFissionRecoilBack = requiredFissionRecoilBack
            processor.requiredRecoil = requiredRecoil
            processor.recoilFrontMinEnergy = sMinRecoilEnergy.doubleValue
            processor.recoilFrontMaxEnergy = sMaxRecoilEnergy.doubleValue
            processor.recoilMinTime = UInt64(sMinRecoilTime.doubleValue)
            processor.recoilMaxTime = UInt64(sMaxRecoilTime.doubleValue)
            processor.recoilBackMaxTime = UInt64(sMaxRecoilBackTime.doubleValue)
            
            processor.minTOFValue = sMinTOFValue.doubleValue
            processor.maxTOFValue = sMaxTOFValue.doubleValue
            processor.unitsTOF = tofUnitsControl.selectedSegment == 0 ? .channels : .nanoseconds
            processor.maxTOFTime = UInt64(sMaxTOFTime.doubleValue)
            processor.requiredTOF = requiredTOF
            
            processor.maxGammaTime = UInt64(sMaxGammaTime.doubleValue)
            processor.requiredGamma = requiredGamma
            
            processor.searchNeutrons = searchNeutrons
            processor.maxNeutronTime = UInt64(sMaxNeutronTime.doubleValue)
            
            processor.searchSpecialEvents = searchSpecialEvents
            let ids = specialEventIds.components(separatedBy: ",").map({ (s: String) -> Int in
                return Int(s) ?? 0
            }).filter({ (i: Int) -> Bool in
                return i > 0
            })
            processor.specialEventIds = ids
            
            processor.delegate = self
            processor.processDataWithCompletion({ [weak self] in
                self?.run = false
            })
        }
    }
    
    fileprivate var run: Bool = false {
        didSet {
            buttonRun.title = run ? "Stop" : "Start"
            if run {
                activity?.startAnimation(self)
                startTimer()
                progressIndicator?.startAnimation(self)
                saveSettings()
            } else {
                activity?.stopAnimation(self)
                stopTimer()
                progressIndicator.stopAnimation(self)
                progressIndicator?.doubleValue = 0.0
            }
            fissionAlphaControl?.isEnabled = !run
            tofUnitsControl?.isEnabled = !run
        }
    }
    
    @IBAction func selectData(_ sender: AnyObject?) {
        Processor.singleton.selectDataWithCompletion { [weak self] (success: Bool) in
            self?.setSelected(success, indicator: self?.indicatorData)
        }
    }
    
    @IBAction func selectCalibration(_ sender: AnyObject?) {
        Processor.singleton.selectCalibrationWithCompletion { [weak self] (success: Bool) in
            self?.setSelected(success, indicator: self?.indicatorCalibration)
        }
    }
    
    // MARK: - ProcessorDelegate
    
    func incrementProgress(_ delta: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progressIndicator?.increment(by: delta)
        }
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
        Settings.setObject(sMinTOFValue.integerValue, forSetting: .MinTOFValue)
        Settings.setObject(sMaxTOFValue.integerValue, forSetting: .MaxTOFValue)
        Settings.setObject(tofUnitsControl.selectedSegment, forSetting: .TOFUnits)
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
        Settings.setObject(searchNeutrons, forSetting: .SearchNeutrons)
        Settings.setObject(fissionAlphaControl.selectedSegment, forSetting: .SearchType)
        Settings.setObject(searchAlpha2, forSetting: .SearchAlpha2)
        Settings.setObject(sMinAlpha2Energy.doubleValue, forSetting: .MinAlpha2Energy)
        Settings.setObject(sMaxAlpha2Energy.doubleValue, forSetting: .MaxAlpha2Energy)
        Settings.setObject(sMinAlpha2Time.integerValue, forSetting: .MinAlpha2Time)
        Settings.setObject(sMaxAlpha2Time.integerValue, forSetting: .MaxAlpha2Time)
        Settings.setObject(sMaxAlpha2FrontDeltaStrips.integerValue, forSetting: .MaxAlpha2FrontDeltaStrips)
        Settings.setObject(searchSpecialEvents, forSetting: .SearchSpecialEvents)
        Settings.setObject(specialEventIds, forSetting: .SpecialEventIds)
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
        let branch = infoPlistStringForKey("CFBundleVersionGitBranch") ?? "unknown"
        labelBranch?.stringValue = "Branch: " + branch
    }
    
}
