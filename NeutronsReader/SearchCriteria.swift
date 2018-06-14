//
//  SearchCriteria.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 13/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class SearchCriteria {
    
    var resultsFolderName: String = ""
    var startParticleType: SearchType = .fission
    var secondParticleType: SearchType = .fission
    var fissionAlphaFrontMinEnergy: Double = 0
    var fissionAlphaFrontMaxEnergy: Double = 0
    var searchFissionAlphaBackByFact: Bool = true
    var recoilFrontMinEnergy: Double = 0
    var recoilFrontMaxEnergy: Double = 0
    var minTOFValue: Double = 0
    var maxTOFValue: Double = 0
    var beamEnergyMin: Float = 0
    var beamEnergyMax: Float = 0
    var recoilMinTime: CUnsignedLongLong = 0
    var recoilMaxTime: CUnsignedLongLong = 0
    var recoilBackMaxTime: CUnsignedLongLong = 0
    var fissionAlphaMaxTime: CUnsignedLongLong = 0
    var recoilBackBackwardMaxTime: CUnsignedLongLong = 0
    var fissionAlphaBackBackwardMaxTime: CUnsignedLongLong = 0
    var fissionAlphaWellBackwardMaxTime: CUnsignedLongLong = 0
    var maxTOFTime: CUnsignedLongLong = 0
    var maxVETOTime: CUnsignedLongLong = 0
    var maxGammaTime: CUnsignedLongLong = 0
    var maxNeutronTime: CUnsignedLongLong = 0
    var recoilFrontMaxDeltaStrips: Int = 0
    var recoilBackMaxDeltaStrips: Int = 0
    var summarizeFissionsAlphaFront = false
    var requiredFissionAlphaBack = false
    var requiredRecoilBack = false
    var requiredRecoil = false
    var requiredGamma = false
    var requiredTOF = false
    var requiredVETO = false
    var searchVETO = false
    var trackBeamEnergy = false
    var trackBeamCurrent = false
    var trackBeamBackground = false
    var trackBeamIntegral = false
    var searchNeutrons = false
    var searchFissionAlpha2 = false
    var fissionAlpha2MinEnergy: Double = 0
    var fissionAlpha2MaxEnergy: Double = 0
    var fissionAlpha2MinTime: CUnsignedLongLong = 0
    var fissionAlpha2MaxTime: CUnsignedLongLong = 0
    var fissionAlpha2MaxDeltaStrips: Int = 0
    var searchSpecialEvents = false
    var searchWell = true
    var specialEventIds = [Int]()
    var unitsTOF: TOFUnits = .channels
    var recoilType: SearchType = .recoil {
        didSet {
            _heavyType = recoilType == .recoil ? .heavy : .recoil
        }
    }
    fileprivate var _heavyType: SearchType = .heavy
    var heavyType: SearchType {
        return _heavyType
    }
    
}
