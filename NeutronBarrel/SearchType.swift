//
//  SearchType.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 16/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

enum SearchType: Int {
    case alpha
    case recoil
    case veto
    case tof
    case tof2
    case gamma
    
    func symbol() -> String {
        switch self {
        case .alpha, .veto:
            return "A"
        case .recoil:
            return "R"
        case .tof, .tof2:
            return "T"
        case .gamma:
            return ""
        }
    }
    
    func name() -> String {
        switch self {
        case .alpha:
            return "Alpha"
        case .veto:
            return "Veto"
        case .recoil:
            return "Recoil"
        case .tof:
            return "TOF"
        case .tof2:
            return "TOF2"
        case .gamma:
            return "Gamma"
        }
    }
}
