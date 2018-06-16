//
//  BeamState.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 16/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class BeamState {
    
    var energy: Event?
    var current: Event?
    var background: Event?
    var integral: Event?
    
    /**
     Method return 'true' if all beam parameters were found for criteria.
     */
    func handleEvent(_ event: Event, criteria: SearchCriteria, dataProtocol: DataProtocol) -> Bool {
        let includeEnergy = criteria.trackBeamEnergy
        let includeCurrent = criteria.trackBeamCurrent
        let includeBackground = criteria.trackBeamBackground
        let includeIntegral = criteria.trackBeamIntegral
        
        func allFound() -> Bool {
            if (includeEnergy && nil == energy) || (includeCurrent && nil == current) || (includeBackground && nil == background) || (includeIntegral && nil == integral) {
                return false
            } else {
                return true
            }
        }
        
        let id = Int(event.eventId)
        if dataProtocol.isBeamEnergy(id) {
            if includeEnergy {
                energy = event
                return allFound()
            }
        } else if dataProtocol.isBeamCurrent(id) {
            if includeCurrent {
                current = event
                return allFound()
            }
        } else if dataProtocol.isBeamBackground(id) {
            if includeBackground {
                background = event
                return allFound()
            }
        } else if dataProtocol.isBeamIntegral(id) {
            if includeIntegral {
                integral = event
                return allFound()
            }
        }
        
        return false
    }
    
    func clean() {
        energy = nil
        current = nil
        background = nil
        integral = nil
    }
    
}
