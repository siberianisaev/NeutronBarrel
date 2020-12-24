//
//  Settings.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 19.03.15.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

enum Setting: String {
    case
    MinFissionEnergy = "MinFissionEnergy",
    MaxFissionEnergy = "MaxFissionEnergy",
    MinFissionBackEnergy = "MinFissionBackEnergy",
    MaxFissionBackEnergy = "MaxFissionBackEnergy",
    MinRecoilFrontEnergy = "MinRecoilFrontEnergy",
    MaxRecoilFrontEnergy = "MaxRecoilFrontEnergy",
    MinRecoilBackEnergy = "MinRecoilBackEnergy",
    MaxRecoilBackEnergy = "MaxRecoilBackEnergy",
    MinTOFValue = "MinTOFValue",
    MaxTOFValue = "MaxTOFValue",
    TOFUnits = "TOFUnits",
    MinRecoilTime = "MinRecoilTime",
    MaxRecoilTime = "MaxRecoilTime",
    MaxRecoilBackTime = "MaxRecoilBackTime",
    MaxRecoilBackBackwardTime = "MaxRecoilBackBackwardTime",
    MaxFissionTime = "MaxFissionTime",
    MaxFissionBackBackwardTime = "MaxFissionBackBackwardTime",
    MaxFissionWellBackwardTime = "MaxFissionWellBackwardTime",
    MaxTOFTime = "MaxTOFTime",
    MaxVETOTime = "MaxVETOTime",
    MaxGammaTime = "MaxGammaTime",
    MaxNeutronTime = "MaxNeutronTime",
    MaxRecoilFrontDeltaStrips = "MaxRecoilFrontDeltaStrips",
    MaxRecoilBackDeltaStrips = "MaxRecoilBackDeltaStrips",
    SummarizeFissionsFront = "SummarizeFissionsFront",
    SummarizeFissionsFront2 = "SummarizeFissionsFront2",
    RequiredFissionAlphaBack = "RequiredFissionAlphaBack",
    RequiredRecoilBack = "RequiredRecoilBack",
    RequiredRecoil = "RequiredRecoil",
    RequiredGamma = "RequiredGamma",
    SimplifyGamma = "SimplifyGamma",
    RequiredWell = "RequiredWell",
    WellRecoilsAllowed = "WellRecoilsAllowed",
    SearchExtraFromParticle2 = "SearchExtraFromParticle2",
    RequiredTOF = "RequiredTOF",
    UseTOF2 = "UseTOF2",
    RequiredVETO = "RequiredVETO",
    SearchNeutrons = "SearchNeutrons",
    StartSearchType = "StartSearchType",
    StartBackSearchType = "StartBackSearchType",
    SecondFrontSearchType = "SecondFrontSearchType",
    SecondBackSearchType = "SecondBackSearchType",
    WellBackSearchType = "WellBackSearchType",
    SearchFissionAlpha2 = "SearchFissionAlpha2",
    SearchVETO = "SearchVETO",
    TrackBeamEnergy = "TrackBeamEnergy",
    TrackBeamCurrent = "TrackBeamCurrent",
    TrackBeamBackground = "TrackBeamBackground",
    TrackBeamIntegral = "TrackBeamIntegral",
    MinFissionAlpha2Energy = "MinFissionAlpha2Energy",
    MaxFissionAlpha2Energy = "MaxFissionAlpha2Energy",
    MinFissionAlpha2BackEnergy = "MinFissionAlpha2BackEnergy",
    MaxFissionAlpha2BackEnergy = "MaxFissionAlpha2BackEnergy",
    MinFissionAlpha2Time = "MinFissionAlpha2Time",
    MaxFissionAlpha2Time = "MaxFissionAlpha2Time",
    MaxFissionAlpha2FrontDeltaStrips = "MaxFissionAlpha2FrontDeltaStrips",
    MaxConcurrentOperations = "MaxConcurrentOperations",
    SearchSpecialEvents = "SearchSpecialEvents",
    SpecialEventIds = "SpecialEventIds",
    GammaEncodersOnly = "GammaEncodersOnly",
    GammaEncoderIds = "GammaEncoderIds",
    SelectedRecoilType = "SelectedRecoilType",
    SelectedRecoilBackType = "SelectedRecoilBackType",
    SearchFissionBackByFact = "SearchFissionBackByFact",
    SearchFissionBack2ByFact = "SearchFissionBack2ByFact",
    SearchRecoilBackByFact = "SearchRecoilBackByFact",
    SearchWell = "SearchWell",
    BeamEnergyMin = "BeamEnergyMin",
    BeamEnergyMax = "BeamEnergyMax",
    ResultsFolderName = "ResultsFolderName",
    FocalDetectorType = "FocalDetectorType"
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
        case .MaxConcurrentOperations:
            return 8
        case .BeamEnergyMin:
            return 200
        case .BeamEnergyMax:
            return 300
        case .MinFissionEnergy, .MaxFissionAlpha2Energy, .MaxFissionAlpha2BackEnergy, .MaxRecoilFrontEnergy, .MaxRecoilBackEnergy:
            return 20
        case .MaxFissionAlpha2Time, .MaxFissionEnergy, .MaxRecoilTime:
            return 1000
        case .MinRecoilFrontEnergy, .MinRecoilBackEnergy:
            return 1
        case .MaxFissionBackEnergy, .MaxTOFValue:
            return 10000
        case .MaxRecoilBackTime, .MaxFissionTime, .MaxVETOTime, .MaxGammaTime, .MinFissionAlpha2Energy, .MinFissionAlpha2BackEnergy:
            return 5
        case .MaxTOFTime:
            return 4
        case .MaxNeutronTime:
            return 132
        case .MinFissionBackEnergy, .MaxRecoilFrontDeltaStrips, .MaxRecoilBackDeltaStrips, .SearchFissionAlpha2, .StartSearchType, .StartBackSearchType, .WellBackSearchType, .SecondFrontSearchType, .SecondBackSearchType, .TOFUnits, .MinFissionAlpha2Time, .MaxFissionAlpha2FrontDeltaStrips, .MinRecoilTime, .MinTOFValue, .MaxFissionBackBackwardTime, .MaxFissionWellBackwardTime, .MaxRecoilBackBackwardTime:
            return 0
        case .RequiredFissionAlphaBack, .RequiredRecoilBack, .SearchNeutrons, .TrackBeamEnergy, .TrackBeamCurrent, .TrackBeamBackground, .TrackBeamIntegral, .SearchWell:
            return true
        case .SummarizeFissionsFront, .SummarizeFissionsFront2, .RequiredRecoil, .RequiredGamma, .SimplifyGamma, .RequiredWell, .WellRecoilsAllowed, .RequiredTOF, .RequiredVETO, .SearchSpecialEvents, .GammaEncodersOnly, .SearchVETO, .SearchFissionBackByFact, .SearchFissionBack2ByFact, .SearchRecoilBackByFact, .UseTOF2, .SearchExtraFromParticle2:
            return false
        case .SpecialEventIds, .GammaEncoderIds:
            return nil
        case .SelectedRecoilType, .SelectedRecoilBackType:
            return SearchType.recoil.rawValue
        case .ResultsFolderName:
            return ""
        case .FocalDetectorType:
            return FocalDetectorType.large
        }
    }
    
}
