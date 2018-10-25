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
        MinNeutronEnergy = "MinNeutronEnergy",
        MaxNeutronEnergy = "MaxNeutronEnergy"
        
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
    
    class func getIntSetting(_ setting: Setting) -> Int {
        let object = getSetting(setting) as? Int
        return object ?? 0
    }
    
    fileprivate class func getSetting(_ setting: Setting) -> Any? {
        let key = setting.key()
        if let object = UserDefaults.standard.object(forKey: key) {
            return object
        }
        
        switch setting {
        case .MinNeutronEnergy:
            return 60
        case .MaxNeutronEnergy:
            return 250
        }
    }
    
}
