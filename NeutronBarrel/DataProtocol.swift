//
//  DataProtocol.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

enum TOFKind: String {
    case TOF = "TOF"
    case TOF2 = "TOF2"
}

class DataProtocol {
    
    
    func keyFor(value: Int) -> String? {
//        if isAlphaFronEvent(value) {
//            return "FocalFront"
//        } else if isAlphaBackEvent(value) {
//            return "FocalBack"
        if isAlphaWellFrontEvent(value) {
            return "WellFront"
        } else if isAlphaWellBackEvent(value) {
            return "WellBack"
        } else if isNeutronsNewEvent(value) {
            return "Neutrons"
        } else if isBeamEnergy(value) {
            return "BeamEnergy"
        } else if isBeamIntegral(value) {
            return "Integral"
        } else if isBeamCurrent(value) {
            return "Current"
        } else if isBeamBackground(value) {
            return "Background"
        } else if isGammaEvent(value) {
            return "Gamma"
        } else {
            // TODO: !!!
            return ""
        }
    }

//    let eventIdsFocalFront = Set(0...127)
//    let eventIdsFocalBack = Set(128...255)
    let wellFrontIds = Array(256...383)
    let wellBackIds = Array(384...511)
    lazy var eventIdsWellFront: Set = {
        Set(wellFrontIds)
    }()
    lazy var eventIdsWellBack: Set = {
        Set(wellBackIds)
    }()
    let eventIdsNeutrons = Set(512...639)
    let eventIdsGamma = Set(640...660)
    let eventIdIntensity = 996 // nA
    let eventIdIntegral = 997 // need multiply on 10! to mkA
    let eventIdBackground = 998 // Hz
    let eventIdEnergy = 999 // need to divide on 10 to MeV
    
    func isAlpha(_ eventId: Int) ->  Bool {
        return isAlphaWellEvent(eventId) // isAlphaFronEvent(eventId) || isAlphaBackEvent(eventId) || isAlphaWellEvent(eventId)
    }
    
    func isAlphaWellEvent(_ eventId: Int) -> Bool {
        return eventIdsWellFront.contains(eventId) || eventIdsWellBack.contains(eventId)
    }
    
    func isAlphaWellFrontEvent(_ eventId: Int) -> Bool {
        return eventIdsWellFront.contains(eventId)
    }
    
    func isAlphaWellBackEvent(_ eventId: Int) -> Bool {
        return eventIdsWellBack.contains(eventId)
    }
    
    func isNeutronsNewEvent(_ eventId: Int) -> Bool {
        return eventIdsNeutrons.contains(eventId)
    }
    
    func isGammaEvent(_ eventId: Int) -> Bool {
        return eventIdsGamma.contains(eventId)
    }
    
    func isBeamEnergy(_ eventId: Int) -> Bool {
        return eventIdEnergy == eventId
    }
    
    func isBeamCurrent(_ eventId: Int) -> Bool {
        return eventIdIntensity == eventId
    }
    
    func isBeamBackground(_ eventId: Int) -> Bool {
        return eventIdBackground == eventId
    }
    
    func isBeamIntegral(_ eventId: Int) -> Bool {
        return eventIdIntegral == eventId
    }
    
}
