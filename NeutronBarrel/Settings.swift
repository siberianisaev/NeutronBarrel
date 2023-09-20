//
//  Settings.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 19.03.15.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

enum Setting: String {
    case
    NeutronsDetectorEfficiency = "NeutronsDetectorEfficiency",
    NeutronsDetectorEfficiencyError = "NeutronsDetectorEfficiencyError",
    ExcludeNeutronCounters = "ExcludeNeutronCounters",
    MinFissionWellEnergy = "MinFissionWellEnergy",
    MaxFissionWellEnergy = "MaxFissionWellEnergy",
    MaxFissionWellAngle = "MaxFissionWellAngle",
    MaxFissionWellBackwardTime = "MaxFissionWellBackwardTime",
    MaxGammaTime = "MaxGammaTime",
    MaxGammaBackwardTime = "MaxGammaBackwardTime",
    MinNeutronTime = "MinNeutronTime",
    MaxNeutronTime = "MaxNeutronTime",
    MaxNeutronBackwardTime = "MaxNeutronBackwardTime",
    RequiredGamma = "RequiredGamma",
    SimplifyGamma = "SimplifyGamma",
    SearchNeutrons = "SearchNeutrons",
    NeutronsBackground = "NeutronsBackground",
    SimultaneousDecaysFilterForNeutrons = "SimultaneousDecaysFilterForNeutrons",
    CollapseNeutronOverlays = "CollapseNeutronOverlays",
    NeutronsPositions = "NeutronsPositions",
    TrackBeamEnergy = "TrackBeamEnergy",
    TrackBeamCurrent = "TrackBeamCurrent",
    TrackBeamBackground = "TrackBeamBackground",
    TrackBeamIntegral = "TrackBeamIntegral",
    MaxConcurrentOperations = "MaxConcurrentOperations",
    SearchSpecialEvents = "SearchSpecialEvents",
    SpecialEventIds = "SpecialEventIds",
    GammaEncodersOnly = "GammaEncodersOnly",
    GammaEncoderIds = "GammaEncoderIds",
    SearchWell = "SearchWell",
    ResultsFolderName = "ResultsFolderName",
    InBeamOnly = "InBeamOnly",
    UseOverflow = "UseOverflow",
    UsePileUp = "UsePileUp"
}

class Settings {
    
    fileprivate static let keySettings = "Settings"
    
    class func change(_ dict: [Setting: Any?]) {
        var info = [String: Any]()
        for (setting, object) in dict {
            if let object = object {
                info[setting.rawValue] = object
            }
        }
        let ud = UserDefaults.standard
        ud.set(info, forKey: keySettings)
        ud.synchronize()
    }
    
    class func changeSingle(_ name: Setting, value: Any?) {
        let ud = UserDefaults.standard
        var settings: [String: Any] = (ud.value(forKey: keySettings) as? [String: Any]) ?? [:]
        settings[name.rawValue] = value
        ud.set(settings, forKey: keySettings)
        ud.synchronize()
    }
    
    class func getStringSetting(_ setting: Setting) -> String? {
        return getSetting(setting) as? String
    }
    
    class func getDoubleSetting(_ setting: Setting) -> Double {
        let object = getSetting(setting) as? Double
        return object ?? 0
    }
    
    class func getUInt64Setting(_ setting: Setting, defaultValue: UInt64 = 0) -> UInt64 {
        let object = getSetting(setting) as? UInt64
        return object ?? defaultValue
    }
    
    class func getIntSetting(_ setting: Setting, defaultValue: Int = 0) -> Int {
        let object = getSetting(setting) as? Int
        return object ?? defaultValue
    }
    
    class func getBoolSetting(_ setting: Setting) -> Bool {
        let object = getSetting(setting) as? Bool
        return object ?? false
    }
    
    fileprivate class func currentSettings() -> [String: Any]? {
        return UserDefaults.standard.object(forKey: keySettings) as? [String: Any]
    }
    
    class func readFromFile(_ completion: @escaping ((Bool)->())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                var success: Bool = false
                if let url = panel.urls.first {
                    do {
                        let data = try Data(contentsOf: url)
                        if let dict = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any] {
                            let ud = UserDefaults.standard
                            ud.set(dict, forKey: keySettings)
                            ud.synchronize()
                            success = true
                        }
                    } catch {
                        print(error)
                    }
                }
                completion(success)
            }
        }
    }
    
    class func writeToFile(_ fileURL: URL?) {
        if let dict = currentSettings(), let url = fileURL {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
                try data.write(to: url)
            } catch {
                print(error)
            }
        }
    }
    
    fileprivate class func getSetting(_ setting: Setting) -> Any? {
        let key = setting.rawValue
        if let object = currentSettings()?[key] {
            return object
        }
        
        switch setting {
        case .NeutronsDetectorEfficiency:
            return 43
        case .MaxConcurrentOperations:
            return 8
        case .MaxFissionWellEnergy:
            return 1000
        case .MaxFissionWellAngle:
            return 10
        case .NeutronsDetectorEfficiencyError:
            return 1
        case .MaxGammaTime, .MaxNeutronBackwardTime:
            return 5
        case .MaxNeutronTime:
            return 132
        case .MaxFissionWellBackwardTime, .MinFissionWellEnergy, .MaxGammaBackwardTime, .MinNeutronTime:
            return 0
        case .SearchNeutrons, .TrackBeamEnergy, .TrackBeamCurrent, .TrackBeamBackground, .TrackBeamIntegral, .SearchWell:
            return true
        case .RequiredGamma, .SimplifyGamma, .SearchSpecialEvents, .GammaEncodersOnly, .NeutronsPositions, .NeutronsBackground, .SimultaneousDecaysFilterForNeutrons, .CollapseNeutronOverlays, .InBeamOnly, .UseOverflow, .UsePileUp:
            return false
        case .SpecialEventIds, .GammaEncoderIds:
            return nil
        case .ResultsFolderName, .ExcludeNeutronCounters:
            return ""
        }
    }
    
}
