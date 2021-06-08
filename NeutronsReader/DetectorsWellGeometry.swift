//
//  DetectorsWellGeometry.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 25/04/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

struct PointXYZ {
    
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    
    init(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    func angleFrom(point: PointXYZ) -> CGFloat {
        let hypotenuse = sqrt(pow(self.x - point.x, 2) + pow(self.y - point.y, 2) + pow(self.z - point.z, 2))
        let sinus = point.z / hypotenuse
        let arcsinus = asin(sinus) * 180 / CGFloat.pi
        return arcsinus
    }
    
}

class DetectorsWellGeometry {
    
    class func coordinatesXYZ(stripDetector: StripDetector, stripFront0: Int, stripBack0: Int, encoderSide: Int? = nil) -> PointXYZ {
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
            let twoCristalsWidth = SideDetector.activeAreaSize().width * 2
            let sideWidth = twoCristalsWidth + SideDetector.interCristalPadding
            let sripWidth = SideDetector.stripsWidth().front
            let isSecondCristal = encoder % 2 == 0
            let halfStripAndShift: CGFloat = 0.5 + (isSecondCristal ? 16.0 : 0.0)
            
            func position(negative: Bool) -> CGFloat {
                var p = (CGFloat(stripFront0) + halfStripAndShift) * sripWidth
                if negative {
                    p = twoCristalsWidth - p
                }
                /*
                 View on beam (crates on left).
                 Side Si cristals positions with related encoders:
                 - from top left to bottom left ## 1 and 2,
                 - from bottom left to bottom right ## 3 and 4,
                 - from bottom right to top right ## 5 and 6,
                 - from top right to top left ## 7 and 8.
                 */
                if negative && !isSecondCristal || !negative && isSecondCristal {
                    p += SideDetector.interCristalPadding
                }
                return p
            }
            
            switch encoder {
            case 1...2:
                x = 0
                y = position(negative: true)
            case 3...4:
                x = position(negative: false)
                y = 0
            case 5...6:
                x = sideWidth
                y = position(negative: false)
            case 7...8:
                x = position(negative: true)
                y = sideWidth
            default:
                break
            }
        }
        return PointXYZ(x: x, y: y, z: z)
    }
    
}
