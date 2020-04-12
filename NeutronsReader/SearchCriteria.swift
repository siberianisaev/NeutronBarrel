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
    var focal = [ParticleSearchCriteria]()
    var well: ParticleSearchCriteria?
    var recoil: ParticleSearchCriteria?
    var minTOFValue: Double = 0
    var maxTOFValue: Double = 0
    var beamEnergyMin: Float = 0
    var beamEnergyMax: Float = 0
    var maxTOFTime: CUnsignedLongLong = 0
    var maxVETOTime: CUnsignedLongLong = 0
    var maxGammaTime: CUnsignedLongLong = 0
    var maxNeutronTime: CUnsignedLongLong = 0
    var requiredGamma = false
    var simplifyGamma = false
    var requiredWell = false
    var wellRecoilsAllowed = false
    var searchExtraFromEndParticle = false
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
    var searchSpecialEvents = false
    var specialEventIds = [Int]()
    var unitsTOF: TOFUnits = .channels
    
    func focal(at index: Int) -> ParticleSearchCriteria? {
        if index >= 0, index < focal.count {
            return focal[index]
        } else {
            return nil
        }
    }
    
    func startFromRecoil() -> Bool {
        let type = focal.first?.frontType
        return type == .recoil || type == .heavy
    }
    
}
