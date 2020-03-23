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
    var startParticleBackType: SearchType = .fission
    var secondParticleFrontType: SearchType = .fission
    var secondParticleBackType: SearchType = .fission
    var wellParticleBackType: SearchType = .fission
    var fissionAlphaFrontMinEnergy: Double = 0
    var fissionAlphaFrontMaxEnergy: Double = 0
    var fissionAlphaBackMinEnergy: Double = 0
    var fissionAlphaBackMaxEnergy: Double = 0
    var searchFissionAlphaBackByFact: Bool = true
    var searchFissionAlphaBack2ByFact: Bool = true
    var recoilFrontMinEnergy: Double = 0
    var recoilFrontMaxEnergy: Double = 0
    var recoilBackMinEnergy: Double = 0
    var recoilBackMaxEnergy: Double = 0
    var searchRecoilBackByFact: Bool = false
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
    var summarizeFissionsAlphaFront2 = false
    var requiredFissionAlphaBack = false
    var requiredRecoilBack = false
    var requiredRecoil = false
    var requiredGamma = false
    var simplifyGamma = false
    var requiredWell = false
    var wellRecoilsAllowed = false
    var searchExtraFromParticle2 = false
    var requiredTOF = false
    var useTOF2 = false
    var requiredVETO = false
    var searchVETO = false
    var trackBeamEnergy = false
    var trackBeamCurrent = false
    var trackBeamBackground = false
    var trackBeamIntegral = false
    var trackBeamState: Bool {
        return trackBeamEnergy || trackBeamCurrent || trackBeamBackground || trackBeamIntegral
    }
    var searchNeutrons = false
    var searchFissionAlpha2 = false
    var fissionAlpha2MinEnergy: Double = 0
    var fissionAlpha2MaxEnergy: Double = 0
    var fissionAlpha2BackMinEnergy: Double = 0
    var fissionAlpha2BackMaxEnergy: Double = 0
    var fissionAlpha2MinTime: CUnsignedLongLong = 0
    var fissionAlpha2MaxTime: CUnsignedLongLong = 0
    var fissionAlpha2MaxDeltaStrips: Int = 0
    var searchSpecialEvents = false
    var searchWell = true
    var specialEventIds = [Int]()
    var unitsTOF: TOFUnits = .channels
    var recoilType: SearchType = .recoil
    
    func startFromRecoil() -> Bool {
        return startParticleType == .recoil || startParticleType == .heavy
    }
    
}
