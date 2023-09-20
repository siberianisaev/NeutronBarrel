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
    
    var startParticleType: SearchType = .alpha
    var summarizeFissionsAlphaFront = false
    var fissionAlphaWellMinEnergy: Double = 0
    var fissionAlphaWellMaxEnergy: Double = 0
    var fissionAlphaWellMaxAngle: Double = 0
    var summarizeFissionsAlphaBack = false
    var fissionAlphaMaxTime: CUnsignedLongLong = 5 // TODO: !!!
    var fissionAlphaBackMaxDeltaStrips: Int = 1 // TODO: !!!

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
    
    var requiredGamma = false
    var requiredGammaOrWell = false
    var simplifyGamma = false
    var inBeamOnly = false
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
    
    var gammaEncodersOnly = false
    var gammaEncoderIds = Set<Int>()
    
}
