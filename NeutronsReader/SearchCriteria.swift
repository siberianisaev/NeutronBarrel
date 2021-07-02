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
    var neutronsDetectorEfficiency: Double = 0
    var neutronsDetectorEfficiencyError: Double = 0
    var closedSFSource: Bool = false
    var placedSFSource: SFSource?
    
    var summarizeFissionsAlphaFront = false
    var fissionAlphaFrontMinEnergy: Double = 0
    var fissionAlphaFrontMaxEnergy: Double = 0
    var fissionAlphaBackMinEnergy: Double = 0
    var fissionAlphaBackMaxEnergy: Double = 0
    var fissionAlphaWellMinEnergy: Double = 0
    var fissionAlphaWellMaxEnergy: Double = 0
    var fissionAlphaWellMaxAngle: Double = 0
    var searchFissionAlphaBackByFact: Bool = true
    var summarizeFissionsAlphaBack = false
    
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
    var maxGammaBackwardTime: CUnsignedLongLong = 0
    var minGammaEnergy: CUnsignedLongLong = 0
    var maxGammaEnergy: CUnsignedLongLong = 0
    var maxNeutronTime: CUnsignedLongLong = 0
    var maxNeutronBackwardTime: CUnsignedLongLong = 0
    var recoilFrontMaxDeltaStrips: Int = 0
    var recoilBackMaxDeltaStrips: Int = 0
    
    var searchFirstRecoilOnly = false
    var requiredFissionAlphaBack = false
    var requiredRecoilBack = false
    var requiredRecoil = false
    var gammaStart = false
    var requiredGammaOrWell = false
    var simplifyGamma = false
    var requiredWell = false
    var wellRecoilsAllowed = false
    var searchExtraFromLastParticle = false
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
    var neutronsPositions = false
    
    var searchSpecialEvents = false
    var specialEventIds = Set<Int>()
    var gammaEncodersOnly = false
    var gammaEncoderIds = Set<Int>()
    var searchWell = true
    var unitsTOF: TOFUnits = .channels
    
}
