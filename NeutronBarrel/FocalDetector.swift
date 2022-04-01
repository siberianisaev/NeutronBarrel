//
//  FocalDetector.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 25/04/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

enum FocalDetectorType: Int {
    case small = 0
    case large = 1
    
    var stripsCount: (front: Int, back: Int) {
        switch self {
        case .small:
            return (48, 48)
        case .large:
            return (128, 128)
        }
    }
    
    var activeAreaSize: CGSize {
        switch self {
        case .small:
            return CGSize(width: 60, height: 60)
        case .large:
            return CGSize(width: 100, height: 100)
        }
    }
}

class FocalDetector: DoubleSidedDetector {
    
    class var type: FocalDetectorType {
        let value = Settings.getIntSetting(.FocalDetectorType)
        return FocalDetectorType(rawValue: value) ?? .large
    }
    
    override class func stripsCount() -> (front: Int, back: Int) {
        return type.stripsCount
    }
    
    override class func activeAreaSize() -> CGSize {
        return type.activeAreaSize
    }
    
}
