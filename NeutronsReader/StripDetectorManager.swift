//
//  StripDetectorManager.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 02/02/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

enum StripDetector {
    case focal
    case side
}

class StripDetectorManager {
    
    fileprivate var stripsConfigurations = [StripDetector: StripsConfiguration]()
    
    func setStripConfiguration(_ config: StripsConfiguration, detector: StripDetector) {
        stripsConfigurations[detector] = config
    }
    
    func getStripConfigurations(_ detector: StripDetector) -> StripsConfiguration {
        if let sc = stripsConfigurations[detector] {
            return sc
        }
        // Default Config
        let sc = StripsConfiguration(detector: detector)
        setStripConfiguration(sc, detector: detector)
        return sc
    }
    
    func reset() {
        stripsConfigurations.removeAll()
    }
    
    class var singleton : StripDetectorManager {
        struct Static {
            static let sharedInstance : StripDetectorManager = StripDetectorManager()
        }
        return Static.sharedInstance
    }
    
    class func cleanStripConfigs() {
        StripDetectorManager.singleton.stripsConfigurations.removeAll()
    }
    
}
