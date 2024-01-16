//
//  SearchCriteria.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 13/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class SearchCriteria {
    
    var resultsFolderName: String = ""
    var neutronsDetectorEfficiency: Double = 0
    var neutronsDetectorEfficiencyError: Double = 0
    var excludeNeutronCounters = [Int]()
    var placedSFSource: SFSource?
    
    var startParticleType: SearchType = .alpha
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
    var recoilMinTime: CUnsignedLongLong = 0 {
        didSet {
            recoilMinTime.mksToCycles()
        }
    }
    var recoilMaxTime: CUnsignedLongLong = 0 {
        didSet {
            recoilMaxTime.mksToCycles()
        }
    }
    var recoilBackMaxTime: CUnsignedLongLong = 0 {
        didSet {
            recoilBackMaxTime.mksToCycles()
        }
    }
    var fissionAlphaMaxTime: CUnsignedLongLong = 0 {
        didSet {
            fissionAlphaMaxTime.mksToCycles()
        }
    }
    var recoilBackBackwardMaxTime: CUnsignedLongLong = 0 {
        didSet {
            recoilBackBackwardMaxTime.mksToCycles()
        }
    }
    var fissionAlphaBackBackwardMaxTime: CUnsignedLongLong = 0 {
        didSet {
            fissionAlphaBackBackwardMaxTime.mksToCycles()
        }
    }
    var fissionAlphaWellBackwardMaxTime: CUnsignedLongLong = 0 {
        didSet {
            fissionAlphaWellBackwardMaxTime.mksToCycles()
        }
    }
    var maxGammaTime: CUnsignedLongLong = 0 {
        didSet {
            maxGammaTime.mksToCycles()
        }
    }
    var maxGammaBackwardTime: CUnsignedLongLong = 0 {
        didSet {
            maxGammaBackwardTime.mksToCycles()
        }
    }
    var minNeutronTime: CUnsignedLongLong = 0 {
        didSet {
            minNeutronTime.mksToCycles()
        }
    }
    var maxNeutronTime: CUnsignedLongLong = 0 {
        didSet {
            maxNeutronTime.mksToCycles()
        }
    }
    var maxNeutronBackwardTime: CUnsignedLongLong = 0 {
        didSet {
            maxNeutronBackwardTime.mksToCycles()
        }
    }
    var checkNeutronMaxDeltaTimeExceeded: Bool = true
    var recoilFrontMaxDeltaStrips: Int = 0
    var recoilBackMaxDeltaStrips: Int = 0
    
    var searchFirstRecoilOnly = false
    var requiredFissionAlphaBack = false
    var requiredRecoilBack = false
    var requiredRecoil = false
    var requiredGamma = false
    var requiredGammaOrWell = false
    var simplifyGamma = false
    var requiredWell = false
    var wellRecoilsAllowed = false
    var searchExtraFromLastParticle = false
    var inBeamOnly = false
    var outBeamOnly = false
    var useOverflow = false
    var usePileUp = false
    var trackBeamEnergy = false
    var trackBeamCurrent = false
    var trackBeamBackground = false
    var trackBeamIntegral = false
    var trackBeamState: Bool {
        return trackBeamEnergy || trackBeamCurrent || trackBeamBackground || trackBeamIntegral
    }
    var searchNeutrons = false
    var neutronsBackground = false
    var simultaneousDecaysFilterForNeutrons = false
    var collapseNeutronOverlays = false
    var neutronsPositions = false
    
    var next = [Int: SearchNextCriteria]()
    func nextMaxIndex() -> Int? {
        return Array(next.keys).max()
    }
    
    var gammaEncodersOnly = false
    var gammaEncoderIds = Set<Int>()
    var searchWell = true
    
    func startFromRecoil() -> Bool {
        return startParticleType == .recoil
    }
    
}

class SearchNextCriteria {
    
    var summarizeFront = false
    var frontMinEnergy: Double = 0
    var frontMaxEnergy: Double = 0
    var backMinEnergy: Double = 0
    var backMaxEnergy: Double = 0
    var minTime: CUnsignedLongLong = 0
    var maxTime: CUnsignedLongLong = 0
    var maxDeltaStrips: Int = 0
    var backByFact: Bool = true
    var frontType: SearchType = .alpha
    var backType: SearchType = .alpha
    
    init(summarizeFront: Bool, frontMinEnergy: Double, frontMaxEnergy: Double, backMinEnergy: Double, backMaxEnergy: Double, minTime: CUnsignedLongLong, maxTime: CUnsignedLongLong, maxDeltaStrips: Int, backByFact: Bool, frontType: SearchType, backType: SearchType) {
        self.summarizeFront = summarizeFront
        self.frontMinEnergy = frontMinEnergy
        self.frontMaxEnergy = frontMaxEnergy
        self.backMinEnergy = backMinEnergy
        self.backMaxEnergy = backMaxEnergy
        self.minTime = minTime
        self.minTime.mksToCycles()
        self.maxTime = maxTime
        self.maxTime.mksToCycles()
        self.maxDeltaStrips = maxDeltaStrips
        self.backByFact = backByFact
        self.frontType = frontType
        self.backType = backType
    }
    
}
