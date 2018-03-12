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
        MaxFissionTime = "MaxFissionTime",
        MaxFissionBackTime = "MaxFissionBackTime",
        MaxFissionWellTime = "MaxFissionWellTime",
        MaxTOFTime = "MaxTOFTime",
        MaxVETOTime = "MaxVETOTime",
        MaxGammaTime = "MaxGammaTime",
        MaxNeutronTime = "MaxNeutronTime",
        MaxRecoilFrontDeltaStrips = "MaxRecoilFrontDeltaStrips",
        MaxRecoilBackDeltaStrips = "MaxRecoilBackDeltaStrips",
        SummarizeFissionsFront = "SummarizeFissionsFront",
        RequiredFissionAlphaBack = "RequiredFissionAlphaBack",
        RequiredRecoilBack = "RequiredRecoilBack",
        RequiredRecoil = "RequiredRecoil",
        RequiredGamma = "RequiredGamma",
        RequiredTOF = "RequiredTOF",
        RequiredVETO = "RequiredVETO",
        SearchNeutrons = "SearchNeutrons",
        SearchType = "SearchType",
        SearchAlpha2 = "SearchAlpha2",
        SearchVETO = "SearchVETO",
        TrackBeamEnergy = "TrackBeamEnergy",
        TrackBeamCurrent = "TrackBeamCurrent",
        TrackBeamBackground = "TrackBeamBackground",
        TrackBeamIntegral = "TrackBeamIntegral",
        MinAlpha2Energy = "MinAlpha2Energy",
        MaxAlpha2Energy = "MaxAlpha2Energy",
        MinAlpha2Time = "MinAlpha2Time",
        MaxAlpha2Time = "MaxAlpha2Time",
        MaxAlpha2FrontDeltaStrips = "MaxAlpha2FrontDeltaStrips",
        SearchSpecialEvents = "SearchSpecialEvents",
        SpecialEventIds = "SpecialEventIds",
        SelectedRecoilType = "SelectedRecoilType",
        SearchFissionBackByFact = "SearchFissionBackByFact",
        SearchWell = "SearchWell"
        
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
        case .MinFissionEnergy, .MaxAlpha2Energy, .MaxRecoilEnergy:
            return 20
        case .MaxAlpha2Time, .MaxFissionEnergy, .MaxRecoilTime:
            return 1000
        case .MinRecoilEnergy:
            return 1
        case .MaxTOFValue:
            return 10000
        case .MaxRecoilBackTime, .MaxFissionTime, .MaxVETOTime, .MaxGammaTime, .MinAlpha2Energy, .MaxFissionWellTime:
            return 5
        case .MaxTOFTime:
            return 4
        case .MaxNeutronTime:
            return 132
        case .MaxRecoilFrontDeltaStrips, .MaxRecoilBackDeltaStrips, .SearchAlpha2, .SearchType, .TOFUnits, .MinAlpha2Time, .MaxAlpha2FrontDeltaStrips, .MinRecoilTime, .MinTOFValue, .MaxFissionBackTime:
            return 0
        case .RequiredFissionAlphaBack, .RequiredRecoilBack, .SearchNeutrons, .TrackBeamEnergy, .TrackBeamCurrent, .TrackBeamBackground, .TrackBeamIntegral, .SearchWell:
            return true
        case .SummarizeFissionsFront, .RequiredRecoil, .RequiredGamma, .RequiredTOF, .RequiredVETO, .SearchSpecialEvents, .SearchVETO, .SearchFissionBackByFact:
            return false
        case .SpecialEventIds:
            return nil
        case .SelectedRecoilType:
            return SearchType.recoil.rawValue
        }
    }
    
}
