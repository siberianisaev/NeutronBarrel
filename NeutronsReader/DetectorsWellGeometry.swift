//
//  DetectorsWellGeometry.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 25/04/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

class DetectorsWellGeometry {
    
    class func coordinatesXYZ(stripDetector: StripDetector, stripFront0: Int, stripBack0: Int, encoderSide: Int? = nil) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var z: CGFloat = 0
        // Z
        if stripDetector == .side {
            z = (CGFloat(SideDetector.stripsCount().back - stripBack0) - 0.5) * SideDetector.stripsWidth().back
        }
        // XY
        if stripDetector == .focal {
            let sw = FocalDetector.stripsWidth()
            x = (CGFloat(stripBack0) + 0.5) * sw.back
            y = (CGFloat(stripFront0) + 0.5) * sw.front
        } else if let encoder = encoderSide {
            let sideFullWidth = SideDetector.activeAreaSize().width * 2
            let sripWidth = SideDetector.stripsWidth().front
            let halfStripAndShift: CGFloat = 0.5 + (encoder % 2 == 0 ? 16.0 : 0.0)
            switch encoder {
            case 1...2:
                x = 0
                y = sideFullWidth - (CGFloat(stripFront0) + halfStripAndShift) * sripWidth
            case 3...4:
                x = (CGFloat(stripFront0) + halfStripAndShift) * sripWidth
                y = 0
            case 5...6:
                x = sideFullWidth
                y = (CGFloat(stripFront0) + halfStripAndShift) * sripWidth
            case 7...8:
                x = sideFullWidth - (CGFloat(stripFront0) + halfStripAndShift) * sripWidth
                y = sideFullWidth
            default:
                break
            }
        }
        return (x, y, z)
    }
    
}
