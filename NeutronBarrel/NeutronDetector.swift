//
//  NeutronDetector.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 11.05.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

class NeutronDetector {
    
    fileprivate var locations = [Int: CGPoint]()
    
    /**
     Counter coordinates (in mm).
     */
    class func pointFor(counter: Int) -> CGPoint? {
        return singleton.locations[counter]
    }
    
    class var singleton : NeutronDetector {
        struct Static {
            static let sharedInstance : NeutronDetector = NeutronDetector()
        }
        return Static.sharedInstance
    }
    
    init() {
        if let url = Bundle.main.url(forResource: "SFiNx_counters_geometry", withExtension: "csv") {
            do {
                let text = try String(contentsOf: url)
                for row in text.components(separatedBy: CharacterSet.newlines).filter({ !$0.isEmpty }) {
                    let values = row.components(separatedBy: ";")
                    if values.count == 3, let counter = Int(values[0]), let x = Double(values[1]), let y = Double(values[2]) {
                        // TODO: convert them to mm in csv
                        locations[counter] = CGPoint(x: x * 10, y: y * 10)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    /**
     If angle is negative, then neutron is related to fragment from side detector.
     */
    class func angle(neutronPoint: CGPoint, focalFragmentPoint: PointXYZ, sideFragmentPoint: PointXYZ) -> CGFloat {
        // y = mx + k
        let m = (sideFragmentPoint.y - focalFragmentPoint.y)/(sideFragmentPoint.x - focalFragmentPoint.x)
        let k = focalFragmentPoint.y - focalFragmentPoint.x * m
        let altitude = abs(k + m * neutronPoint.x - neutronPoint.y) / sqrt(1 + pow(m, 2))
        let hipotenuse = sqrt(pow(focalFragmentPoint.x - neutronPoint.x, 2) + pow(focalFragmentPoint.y - neutronPoint.y, 2))
        let sinus = altitude / hipotenuse
        let angle = asin(sinus) * 180 / CGFloat.pi
        
        func isAtBottomOfPerpindicularLineToFocalFragment(x: CGFloat, y: CGFloat) -> Bool {
            let perpendicularY = (-1/m)*(x - focalFragmentPoint.x) + focalFragmentPoint.y
            return y < perpendicularY
        }
        
        if isAtBottomOfPerpindicularLineToFocalFragment(x: neutronPoint.x, y: neutronPoint.y) == isAtBottomOfPerpindicularLineToFocalFragment(x: sideFragmentPoint.x, y: sideFragmentPoint.y)  {
            return -angle
        } else {
            return angle
        }
    }
    
}
