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
    
    func configName() -> String {
        switch self {
        case .focal:
            return "128x128"
        default:
            return "welstrip"
        }
    }
}

class StripDetectorManager {
    
    var stripsConfigurations = [StripDetector: StripsConfiguration]()
    
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
