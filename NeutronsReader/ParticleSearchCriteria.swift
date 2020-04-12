//
//  ParticleSearchCriteria.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.04.2020.
//  Copyright © 2020 Flerov Laboratory. All rights reserved.
//

import Cocoa

class ParticleSearchCriteria: NSObject {
    
    // Front
    var frontRequired: Bool = false
    var frontTimeMin: UInt64 = 0
    var frontTimeMax: UInt64 = 0
    var frontNextTimeMax: UInt64 = 0
    var frontBackwardTimeMax: UInt64 = 0
    var frontType: SearchType = .fission
    var frontEnergyMin: Double = 0
    var frontEnergyMax: Double = 0
    var frontSummarization: Bool = false
    var frontMaxDeltaStrips: Int = 0
    
    // Back
    var backType: SearchType = .fission
    var backByFact: Bool = false
    var backEnergyMin: Double = 0
    var backEnergyMax: Double = 0
    var backRequired: Bool = false
    var backTimeMax: UInt64 = 0
    var backBackwardTimeMax: UInt64 = 0
    var backMaxDeltaStrips: Int = 0

}
