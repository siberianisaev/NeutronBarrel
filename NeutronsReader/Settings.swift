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
    NeutronsDetectorEfficiency = "NeutronsDetectorEfficiency",
    NeutronsDetectorEfficiencyError = "NeutronsDetectorEfficiencyError",
    SFSourcePlaced = "SFSourcePlaced",
    SFSource = "SFSource",
    MinFissionEnergy = "MinFissionEnergy",
    MaxFissionEnergy = "MaxFissionEnergy",
    MinFissionBackEnergy = "MinFissionBackEnergy",
    MaxFissionBackEnergy = "MaxFissionBackEnergy",
    MinRecoilFrontEnergy = "MinRecoilFrontEnergy",
    MaxRecoilFrontEnergy = "MaxRecoilFrontEnergy",
    MinRecoilBackEnergy = "MinRecoilBackEnergy",
    MaxRecoilBackEnergy = "MaxRecoilBackEnergy",
    MinFissionWellEnergy = "MinFissionWellEnergy",
    MaxFissionWellEnergy = "MaxFissionWellEnergy",
    MaxFissionWellAngle = "MaxFissionWellAngle",
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
    MaxGammaBackwardTime = "MaxGammaBackwardTime",
    MaxNeutronTime = "MaxNeutronTime",
    MaxNeutronBackwardTime = "MaxNeutronBackwardTime",
    MaxRecoilFrontDeltaStrips = "MaxRecoilFrontDeltaStrips",
    MaxRecoilBackDeltaStrips = "MaxRecoilBackDeltaStrips",
    SummarizeFissionsFront = "SummarizeFissionsFront",
    SummarizeFissionsFront2 = "SummarizeFissionsFront2",
    SummarizeFissionsFront3 = "SummarizeFissionsFront3",
    SummarizeFissionsBack = "SummarizeFissionsBack",
    RequiredFissionAlphaBack = "RequiredFissionAlphaBack",
    SearchFirstRecoilOnly = "SearchFirstRecoilOnly",
    RequiredRecoilBack = "RequiredRecoilBack",
    RequiredRecoil = "RequiredRecoil",
    RequiredGamma = "RequiredGamma",
    RequiredGammaOrWell = "RequiredGammaOrWell",
    SimplifyGamma = "SimplifyGamma",
    RequiredWell = "RequiredWell",
    WellRecoilsAllowed = "WellRecoilsAllowed",
    SearchExtraFromLastParticle = "SearchExtraFromLastParticle",
    RequiredTOF = "RequiredTOF",
    UseTOF2 = "UseTOF2",
    RequiredVETO = "RequiredVETO",
    SearchNeutrons = "SearchNeutrons",
    NeutronsPositions = "NeutronsPositions",
    StartSearchType = "StartSearchType",
    StartBackSearchType = "StartBackSearchType",
    SecondFrontSearchType = "SecondFrontSearchType",
    SecondBackSearchType = "SecondBackSearchType",
    ThirdFrontSearchType = "ThirdFrontSearchType",
    ThirdBackSearchType = "ThirdBackSearchType",
    WellBackSearchType = "WellBackSearchType",
    SearchFissionAlpha1 = "SearchFissionAlpha1",
    SearchFissionAlpha2 = "SearchFissionAlpha2",
    SearchFissionAlpha3 = "SearchFissionAlpha3",
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
    MinFissionAlpha3Energy = "MinFissionAlpha3Energy",
    MaxFissionAlpha3Energy = "MaxFissionAlpha3Energy",
    MinFissionAlpha3BackEnergy = "MinFissionAlpha3BackEnergy",
    MaxFissionAlpha3BackEnergy = "MaxFissionAlpha3BackEnergy",
    MinFissionAlpha3Time = "MinFissionAlpha3Time",
    MaxFissionAlpha3Time = "MaxFissionAlpha3Time",
    MaxFissionAlpha3FrontDeltaStrips = "MaxFissionAlpha3FrontDeltaStrips",
    MaxConcurrentOperations = "MaxConcurrentOperations",
    SearchSpecialEvents = "SearchSpecialEvents",
    SpecialEventIds = "SpecialEventIds",
    GammaEncodersOnly = "GammaEncodersOnly",
    GammaEncoderIds = "GammaEncoderIds",
    SelectedRecoilType = "SelectedRecoilType",
    SelectedRecoilBackType = "SelectedRecoilBackType",
    SearchFissionBackByFact = "SearchFissionBackByFact",
    SearchFissionBack2ByFact = "SearchFissionBack2ByFact",
    SearchFissionBack3ByFact = "SearchFissionBack3ByFact",
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
        case .BeamEnergyMin:
            return 200
        case .BeamEnergyMax:
            return 300
        case .MinFissionEnergy, .MaxFissionAlpha2Energy, .MaxFissionAlpha2BackEnergy, .MaxFissionAlpha3Energy, .MaxFissionAlpha3BackEnergy, .MaxRecoilFrontEnergy, .MaxRecoilBackEnergy:
            return 20
        case .MaxFissionAlpha2Time, .MaxFissionAlpha3Time, .MaxFissionEnergy, .MaxRecoilTime, .MaxFissionWellEnergy:
            return 1000
        case .MaxFissionWellAngle:
            return 10
        case .MinRecoilFrontEnergy, .MinRecoilBackEnergy, .NeutronsDetectorEfficiencyError:
            return 1
        case .MaxFissionBackEnergy, .MaxTOFValue:
            return 10000
        case .MaxRecoilBackTime, .MaxFissionTime, .MaxVETOTime, .MaxGammaTime, .MinFissionAlpha2Energy, .MinFissionAlpha2BackEnergy, .MinFissionAlpha3Energy, .MinFissionAlpha3BackEnergy, .MaxNeutronBackwardTime:
            return 5
        case .MaxTOFTime:
            return 4
        case .MaxNeutronTime:
            return 132
        case .MinFissionBackEnergy, .MaxRecoilFrontDeltaStrips, .MaxRecoilBackDeltaStrips, .SearchFissionAlpha1, .SearchFissionAlpha2, .SearchFissionAlpha3, .StartSearchType, .StartBackSearchType, .WellBackSearchType, .SecondFrontSearchType, .SecondBackSearchType, .ThirdFrontSearchType, .ThirdBackSearchType, .TOFUnits, .MinFissionAlpha2Time, .MaxFissionAlpha2FrontDeltaStrips, .MinFissionAlpha3Time, .MaxFissionAlpha3FrontDeltaStrips, .MinRecoilTime, .MinTOFValue, .MaxFissionBackBackwardTime, .MaxFissionWellBackwardTime, .MaxRecoilBackBackwardTime, .MinFissionWellEnergy, .MaxGammaBackwardTime, .SFSource:
            return 0
        case .RequiredFissionAlphaBack, .SearchFirstRecoilOnly, .RequiredRecoilBack, .SearchNeutrons, .TrackBeamEnergy, .TrackBeamCurrent, .TrackBeamBackground, .TrackBeamIntegral, .SearchWell:
            return true
        case .SummarizeFissionsFront, .SummarizeFissionsFront2, .SummarizeFissionsFront3, .SummarizeFissionsBack, .RequiredRecoil, .RequiredGamma, .RequiredGammaOrWell, .SimplifyGamma, .RequiredWell, .WellRecoilsAllowed, .RequiredTOF, .RequiredVETO, .SearchSpecialEvents, .GammaEncodersOnly, .SearchVETO, .SearchFissionBackByFact, .SearchFissionBack2ByFact, .SearchFissionBack3ByFact, .SearchRecoilBackByFact, .UseTOF2, .SearchExtraFromLastParticle, .SFSourcePlaced, .NeutronsPositions:
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
