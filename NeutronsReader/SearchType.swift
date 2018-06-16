//
//  SearchType.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 16/06/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

enum SearchType: Int {
    case fission = 0
    case alpha = 1
    case recoil = 2
    case heavy
    case veto
    
    func symbol() -> String {
        switch self {
        case .fission:
            return "F"
        case .alpha, .veto:
            return "A"
        case .recoil:
            return "R"
        case .heavy:
            return "H"
        }
    }
    
    func name() -> String {
        switch self {
        case .fission:
            return "Fission"
        case .alpha:
            return "Alpha"
        case .veto:
            return "Veto"
        case .recoil:
            return "Recoil"
        case .heavy:
            return "Heavy Recoil"
        }
    }
}
