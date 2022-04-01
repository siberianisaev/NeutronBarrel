//
//  CalibrationEquation.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 16/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class CalibrationEquation {
    
    fileprivate var a: Double = 0
    fileprivate var b: Double = 0
    
    init(a: Double, b: Double) {
        self.a = a
        self.b = b
    }
    
    func applyOn(_ y: Double) -> Double {
        return b + a * y
    }
    
}
