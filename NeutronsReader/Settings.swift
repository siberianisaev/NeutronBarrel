//
//  Settings.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 19.03.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Foundation

class Settings {
    
    enum Setting : String {
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
        MaxTOFTime = "MaxTOFTime",
        MaxGammaTime = "MaxGammaTime",
        MaxNeutronTime = "MaxNeutronTime",
        MaxRecoilFrontDeltaStrips = "MaxRecoilFrontDeltaStrips",
        MaxRecoilBackDeltaStrips = "MaxRecoilBackDeltaStrips",
        SummarizeFissionsFront = "SummarizeFissionsFront",
        RequiredFissionRecoilBack = "RequiredFissionRecoilBack",
        RequiredRecoil = "RequiredRecoil",
        RequiredGamma = "RequiredGamma",
        RequiredTOF = "RequiredTOF",
        SearchNeutrons = "SearchNeutrons",
        SearchType = "SearchType",
        SearchAlpha2 = "SearchAlpha2",
        MinAlpha2Energy = "MinAlpha2Energy",
        MaxAlpha2Energy = "MaxAlpha2Energy",
        MinAlpha2Time = "MinAlpha2Time",
        MaxAlpha2Time = "MaxAlpha2Time",
        MaxAlpha2FrontDeltaStrips = "MaxAlpha2FrontDeltaStrips",
        SearchSpecialEvents = "SearchSpecialEvents",
        SpecialEventIds = "SpecialEventIds"
        
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
    
    class func getStringSetting(_ setting: Setting) -> NSString? {
        if let object = (getSetting(setting) as? NSString) {
            return object
        }
        return nil
    }
    
    class func getDoubleSetting(_ setting: Setting) -> Double {
        if let object = (getSetting(setting) as? Double) {
            return object
        }
        return 0
    }
    
    class func getIntSetting(_ setting: Setting) -> Int {
        if let object = (getSetting(setting) as? Int) {
            return object
        }
        return 0
    }
    
    class func getBoolSetting(_ setting: Setting) -> Bool {
        if let object = (getSetting(setting) as? Bool) {
            return object
        }
        return false
    }
    
    fileprivate class func getSetting(_ setting: Setting) -> Any? {
        let key = setting.key()
        if let object = UserDefaults.standard.object(forKey: key) {
            return object
        }
        
        switch setting {
        case .MinFissionEnergy:
            return 20
        case .MaxFissionEnergy:
            return 1000
        case .MinRecoilEnergy:
            return 1
        case .MaxRecoilEnergy:
            return 20
        case .MinTOFValue:
            return 0
        case .MaxTOFValue:
            return 10000
        case .MinRecoilTime:
            return 0
        case .MaxRecoilTime:
            return 1000
        case .MaxRecoilBackTime:
            return 5
        case .MaxFissionTime:
            return 5
        case .MaxTOFTime:
            return 4
        case .MaxGammaTime:
            return 5
        case .MaxNeutronTime:
            return 132
        case .MaxRecoilFrontDeltaStrips:
            return 0
        case .MaxRecoilBackDeltaStrips:
            return 0
        case .SummarizeFissionsFront:
            return false
        case .RequiredFissionRecoilBack:
            return true
        case .RequiredRecoil:
            return false
        case .RequiredGamma:
            return false
        case .RequiredTOF:
            return false
        case .SearchNeutrons:
            return true
        case .SearchType, .TOFUnits:
            return 0
        case .SearchAlpha2:
            return 0
        case .MinAlpha2Energy:
            return 5
        case .MaxAlpha2Energy:
            return 20
        case .MinAlpha2Time:
            return 0
        case .MaxAlpha2Time:
            return 1000
        case .MaxAlpha2FrontDeltaStrips:
            return 0
        case .SearchSpecialEvents:
            return false
        case .SpecialEventIds:
            return nil
        }
    }
    
}
