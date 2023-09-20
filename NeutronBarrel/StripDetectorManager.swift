//
//  StripDetectorManager.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 02/02/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

enum StripDetector {
//    case focal
    case side
    // TODO: refactoring, extract encoder/channel conversion logic from strips config
    case neutron
    
    /*
     mkm
     */
    func deadLayer() -> CGFloat {
        switch self {
//        case .focal:
//            return 0.1
        case .side:
            return 0.3
        default:
            return 0.0
        }
    }
}

class StripDetectorManager {
    
    var stripConfiguration = StripsConfiguration()
    
//    func setStripConfiguration(_ config: StripsConfiguration, detector: StripDetector) {
//        stripsConfigurations[detector] = config
//    }
//
//    func getStripConfigurations(_ detector: StripDetector) -> StripsConfiguration {
//        if let sc = stripsConfigurations[detector] {
//            return sc
//        }
//        // Default Config
//        let sc = StripsConfiguration()
//        setStripConfiguration(sc, detector: detector)
//        return sc
//    }
//
//    func reset() {
//        stripsConfigurations.removeAll()
//    }
    
    class var singleton : StripDetectorManager {
        struct Static {
            static let sharedInstance : StripDetectorManager = StripDetectorManager()
        }
        return Static.sharedInstance
    }
    
//    class func cleanStripConfigs() {
//        StripDetectorManager.singleton.stripsConfigurations.removeAll()
//    }
    
}
