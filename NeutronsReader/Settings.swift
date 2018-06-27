//
//  Settings.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 19.03.15.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class Settings {
    
    enum Setting: String {
        case
        MinFissionEnergy = "MinFissionEnergy",
        MaxFissionEnergy = "MaxFissionEnergy",
        MinRecoilEnergy = "MinRecoilEnergy",
        MaxRecoilEnergy = "MaxRecoilEnergy",
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
        RequiredTOF = "RequiredTOF",
        RequiredVETO = "RequiredVETO",
        SearchNeutrons = "SearchNeutrons",
        StartSearchType = "StartSearchType",
        SecondSearchType = "SecondSearchType",
        SearchFissionAlpha2 = "SearchFissionAlpha2",
        SearchVETO = "SearchVETO",
        TrackBeamEnergy = "TrackBeamEnergy",
        TrackBeamCurrent = "TrackBeamCurrent",
        TrackBeamBackground = "TrackBeamBackground",
        TrackBeamIntegral = "TrackBeamIntegral",
        MinFissionAlpha2Energy = "MinFissionAlpha2Energy",
        MaxFissionAlpha2Energy = "MaxFissionAlpha2Energy",
        MinFissionAlpha2Time = "MinFissionAlpha2Time",
        MaxFissionAlpha2Time = "MaxFissionAlpha2Time",
        MaxFissionAlpha2FrontDeltaStrips = "MaxFissionAlpha2FrontDeltaStrips",
        MaxConcurrentOperations = "MaxConcurrentOperations",
        SearchSpecialEvents = "SearchSpecialEvents",
        SpecialEventIds = "SpecialEventIds",
        SelectedRecoilType = "SelectedRecoilType",
        SearchFissionBackByFact = "SearchFissionBackByFact",
        SearchFissionBack2ByFact = "SearchFissionBack2ByFact",
        SearchWell = "SearchWell",
        BeamEnergyMin = "BeamEnergyMin",
        BeamEnergyMax = "BeamEnergyMax"
        
        func key() -> String {
            return "Setting.\(self.rawValue)"
        }
    }
    
    class func setObject(_ object: Any?, forSetting setting: Setting) {
        if let object = object {
            let key = setting.key()
            UserDefaults.standard.set(object, forKey: key)
        }
    }
    
    class func getStringSetting(_ setting: Setting) -> String? {
        return getSetting(setting) as? String
    }
    
    class func getDoubleSetting(_ setting: Setting) -> Double {
        let object = getSetting(setting) as? Double
        return object ?? 0
    }
    
    class func getIntSetting(_ setting: Setting) -> Int {
        let object = getSetting(setting) as? Int
        return object ?? 0
    }
    
    class func getBoolSetting(_ setting: Setting) -> Bool {
        let object = getSetting(setting) as? Bool
        return object ?? false
    }
    
    fileprivate class func getSetting(_ setting: Setting) -> Any? {
        let key = setting.key()
        if let object = UserDefaults.standard.object(forKey: key) {
            return object
        }
        
        switch setting {
        case .MaxConcurrentOperations:
            return 8
        case .BeamEnergyMin:
            return 200
        case .BeamEnergyMax:
            return 300
        case .MinFissionEnergy, .MaxFissionAlpha2Energy, .MaxRecoilEnergy:
            return 20
        case .MaxFissionAlpha2Time, .MaxFissionEnergy, .MaxRecoilTime:
            return 1000
        case .MinRecoilEnergy:
            return 1
        case .MaxTOFValue:
            return 10000
        case .MaxRecoilBackTime, .MaxFissionTime, .MaxVETOTime, .MaxGammaTime, .MinFissionAlpha2Energy:
            return 5
        case .MaxTOFTime:
            return 4
        case .MaxNeutronTime:
            return 132
        case .MaxRecoilFrontDeltaStrips, .MaxRecoilBackDeltaStrips, .SearchFissionAlpha2, .StartSearchType, .SecondSearchType, .TOFUnits, .MinFissionAlpha2Time, .MaxFissionAlpha2FrontDeltaStrips, .MinRecoilTime, .MinTOFValue, .MaxFissionBackBackwardTime, .MaxFissionWellBackwardTime, .MaxRecoilBackBackwardTime:
            return 0
        case .RequiredFissionAlphaBack, .RequiredRecoilBack, .SearchNeutrons, .TrackBeamEnergy, .TrackBeamCurrent, .TrackBeamBackground, .TrackBeamIntegral, .SearchWell:
            return true
        case .SummarizeFissionsFront, .SummarizeFissionsFront2, .RequiredRecoil, .RequiredGamma, .RequiredTOF, .RequiredVETO, .SearchSpecialEvents, .SearchVETO, .SearchFissionBackByFact, .SearchFissionBack2ByFact:
            return false
        case .SpecialEventIds:
            return nil
        case .SelectedRecoilType:
            return SearchType.recoil.rawValue
        }
    }
    
}
