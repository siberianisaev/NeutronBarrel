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
        MinTOFChannel = "MinTOFChannel",
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
        SearchType = "SearchType"
        
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
        case .MinTOFChannel:
            return 0
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
        case .SearchType:
            return 0
        }
    }
    
}
