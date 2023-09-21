//
//  ResultsTable.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 12.03.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

protocol ResultsTableDelegate: AnyObject {
    
    func rowsCountForCurrentResult() -> Int
    func neutronsCountWithNewLine() -> Int
    func neutrons() -> NeutronsMatch
    func currentFileEventNumber(_ number: CUnsignedLongLong) -> String
    func focalGammaContainer() -> DetectorMatch?
    func fissionsAlphaWellAt(side: StripsSide, index: Int) -> DetectorMatchItem?
    func beamState() -> BeamState
    func firstParticleAt(side: StripsSide) -> DetectorMatch
    func specialWith(eventId: Int) -> CUnsignedShort?
    func wellDetectorNumber(_ eventId: Int, stripsSide: StripsSide) -> Int
    
}

class ResultsTable {
    
    enum Position: String {
        case X = "X", Y = "Y", Z = "Z"
        
        func relatedCoordinate(point: PointXYZ) -> CGFloat {
            switch self {
            case .X:
                return point.x
            case .Y:
                return point.y
            case .Z:
                return point.z
            }
        }
    }
    
    fileprivate var criteria = SearchCriteria()
    fileprivate var logger: Logger!
    fileprivate weak var delegate: ResultsTableDelegate!
    
    fileprivate var dataProtocol: DataProtocol! {
        return DataLoader.singleton.dataProtocol
    }
    
    init(criteria: SearchCriteria, logger: Logger!, delegate: ResultsTableDelegate) {
        self.criteria = criteria
        self.logger = logger
        self.delegate = delegate
    }
    
    fileprivate var columns = [String]()
    fileprivate var keyColumnRecoilFrontEvent: String {
        return "Event(Recoil)"
    }
    fileprivate var keyRecoil: String {
        return  "R"
    }
    fileprivate var keyColumnRecoilFrontEnergy: String {
        return "E(\(keyRecoil)Fron)"
    }
    fileprivate var keyColumnRecoilFrontOverflow: String {
        return "\(keyRecoil)FronOverflow"
    }
    fileprivate func keyColumnRecoilFrontDeltaTime(log: Bool) -> String {
        var s = ""
        if log {
            s += "Log2"
        }
        s += "dT(\(keyRecoil)Fron-$Fron)"
        return s
    }
    fileprivate var keyColumnRecoilBackEvent: String {
        return "Event(RecoilBack)"
    }
    fileprivate let keyColumnRecoilBackEnergy: String = "E(RBack)"
    fileprivate var keyColumnStartEvent = "Event($)"
    fileprivate var keyColumnStartFrontSum = "Sum($Fron)"
    fileprivate var keyColumnStartFrontEnergy = "$Fron"
    fileprivate var keyColumnStartFrontOverflow = "$FronOverflow"
    fileprivate var keyColumnStartFrontDeltaTime = "dT($FronFirst-Next)"
    fileprivate var keyColumnStartFrontStrip = "Strip($Fron)"
    fileprivate func keyColumnStartFocal(position: Position) -> String {
        return "StartFocalPosition\(position.rawValue)"
    }
    fileprivate var keyColumnStartBackSum = "Sum(@Back)"
    fileprivate var keyColumnStartBackEnergy = "@Back"
    fileprivate var keyColumnStartBackOverflow = "@BackOverflow"
    fileprivate var keyColumnStartBackDeltaTime = "dT($Fron-@Back)"
    fileprivate var keyColumnStartBackStrip = "Strip(@Back)"
    fileprivate var keyColumnWellEnergy: String {
        return "$Well"
    }
    fileprivate var keyColumnWellOverflow = "$WellOverflow"
    fileprivate var keyColumnWellPosition = "$WellPos"
    fileprivate var keyColumnWellDetector = "$WellDetector"
    fileprivate func keyColumnWell(position: Position) -> String {
        return "$WellPos\(position.rawValue)"
    }
    fileprivate var keyColumnWellAngle = "$WellAngle"
    fileprivate var keyColumnWellStrip = "Encoder($Well)" // TODO: strip
    fileprivate var keyColumnWellBackEnergy = "*WellBack"
    fileprivate var keyColumnWellBackOverflow = "*WellBackOverflow"
    fileprivate var keyColumnWellBackPosition = "*WellBackPos"
    fileprivate var keyColumnWellBackStrip = "Encoder(*WellBack)" // TODO: strip
    fileprivate var keyColumnWellRangeInDeadLayers = "WellRangeInDeadLayers"
    fileprivate var keyColumnTKEFront = "TKEFront"
    fileprivate var keyColumnTKEBack = "TKEBack"
    fileprivate var keyColumnNeutronsAverageTime = "NeutronsAverageTime"
    fileprivate var keyColumnNeutronTime = "NeutronTime"
    fileprivate var keyColumnNeutronCounter = "NeutronCounter"
    fileprivate var keyColumnNeutronBlock = "NeutronBlock"
    fileprivate var keyColumnNeutronCounterX = "NeutronCounterX"
    fileprivate var keyColumnNeutronCounterY = "NeutronCounterY"
    fileprivate var keyColumnNeutronAngle = "NeutronAngle"
    fileprivate var keyColumnNeutronRelatedFissionBack = "NeutronRelatedFissionBack"
    fileprivate var keyColumnNeutrons: String {
        var s = "Neutrons"
        if criteria.neutronsBackground {
            s += "(BKG)"
        }
        return s
    }
    fileprivate let keyColumnEvent: String = "Event"
    fileprivate func keyColumnGammaEnergy(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        if criteria.simplifyGamma {
            s += "_Simplified"
        }
        return s
    }
    fileprivate func keyColumnGammaEncoder(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        return s + "Encoder"
    }
    fileprivate func keyColumnGammaStrip(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        return s + "Strip"
    }
    fileprivate func keyColumnGammaDeltaTime(_ max: Bool) -> String {
        var s = "dT($Fron-Gamma"
        if max {
            s += "Max"
        }
        return s + ")"
    }
    fileprivate func keyColumnGammaOverflow(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        return s + "Overflow"
    }
    fileprivate var keyColumnGammaCount = "GammaCount"
    fileprivate var keyColumnGammaSumEnergy = "GammaSumEnergy"
    fileprivate var keyColumnBeamEnergy = "BeamEnergy"
    fileprivate var keyColumnBeamCurrent = "BeamCurrent"
    fileprivate var keyColumnBeamBackground = "BeamBackground"
    fileprivate var keyColumnBeamIntegral = "BeamIntegral"
    fileprivate func keyColumnFissionAlphaFrontSum(_ index: Int) -> String {
        return "Sum(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontEvent(_ index: Int) -> String {
        return "Event(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontEnergy(_ index: Int) -> String {
        return "E(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontOverflow(_ index: Int) -> String {
        return "&Front\(index)Overflow"
    }
    fileprivate func keyColumnFissionAlphaFrontDeltaTime(_ index: Int) -> String {
        return "dT($Front\(index-1)-&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontStrip(_ index: Int) -> String {
        return "Strip(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaBackSum(_ index: Int) -> String {
        return "Sum(^Back\(index))"
    }
    fileprivate func keyColumnFissionAlphaBackEnergy(_ index: Int) -> String {
        return "^Back\(index)"
    }
    fileprivate func keyColumnFissionAlphaBackOverflow(_ index: Int) -> String {
        return "^Back\(index)Overflow"
    }
    fileprivate func keyColumnFissionAlphaBackDeltaTime(_ index: Int) -> String {
        return "dT($Front\(index)-&Back\(index))"
    }
    fileprivate func keyColumnFissionAlphaBackStrip(_ index: Int) -> String {
        return "Strip(^Back\(index))"
    }
    
    fileprivate var columnsGamma = [String]()
    
    func logGammaHeader() {
        if !criteria.simplifyGamma {
            columnsGamma.append(contentsOf: [
                keyColumnEvent,
                keyColumnGammaEnergy(false),
                keyColumnGammaSumEnergy,
                keyColumnGammaEncoder(false),
                keyColumnGammaStrip(false),
                keyColumnGammaDeltaTime(false),
                keyColumnGammaOverflow(false),
                keyColumnGammaCount
            ])
            let headers = setupHeaders(columnsGamma)
            for destination in [.gammaAll, .gammaGeOnly] as [LoggerDestination] {
                logger.writeLineOfFields(headers, destination: destination)
                logger.finishLine(destination) // +1 line padding
            }
        }
    }
    
    func logResultsHeader() {
        columns = []
//        columns.append(contentsOf: [
//            keyColumnRecoilFrontEvent,
//            keyColumnRecoilFrontEnergy,
//            keyColumnRecoilFrontOverflow,
//            keyColumnRecoilFrontDeltaTime(log: false),
//            keyColumnRecoilFrontDeltaTime(log: true),
//            keyColumnRecoilBackEvent,
//            keyColumnRecoilBackEnergy
//        ])
        columns.append(contentsOf: [
            keyColumnStartEvent,
            keyColumnStartFrontSum,
//            keyColumnStartFrontEnergy,
//            keyColumnStartFrontOverflow,
//            keyColumnStartFrontDeltaTime,
//            keyColumnStartFrontStrip
        ])
//        columns.append(contentsOf: ([.X, .Y, .Z] as [Position]).map { keyColumnStartFocal(position: $0) })
        columns.append(contentsOf: [
            keyColumnStartBackSum,
//            keyColumnStartBackEnergy,
//            keyColumnStartBackOverflow,
            keyColumnStartBackDeltaTime,
//            keyColumnStartBackStrip
        ])
        columns.append(contentsOf: [
            keyColumnWellEnergy,
            keyColumnWellOverflow,
            keyColumnWellPosition,
            keyColumnWellDetector
            ])
        columns.append(contentsOf: ([.X, .Y, .Z] as [Position]).map { keyColumnWell(position: $0) })
        columns.append(contentsOf: [
//            keyColumnWellAngle,
//            keyColumnWellStrip,
            keyColumnWellBackEnergy,
            keyColumnWellBackOverflow,
            keyColumnWellBackPosition,
//            keyColumnWellBackStrip,
//            keyColumnWellRangeInDeadLayers,
//            keyColumnTKEFront,
//            keyColumnTKEBack
            ])
        if criteria.searchNeutrons {
            columns.append(contentsOf: [keyColumnNeutronsAverageTime, keyColumnNeutronTime, keyColumnNeutronCounter, keyColumnNeutronBlock, keyColumnNeutrons])
            if criteria.neutronsPositions {
                columns.append(contentsOf: [keyColumnNeutronCounterX, keyColumnNeutronCounterY, keyColumnNeutronAngle, keyColumnNeutronRelatedFissionBack])
            }
        }
        columns.append(contentsOf: [
            keyColumnGammaEnergy(true),
            keyColumnGammaSumEnergy,
            keyColumnGammaEncoder(true),
            keyColumnGammaStrip(true),
            keyColumnGammaDeltaTime(true),
            keyColumnGammaCount
            ])
        if criteria.trackBeamEnergy {
            columns.append(keyColumnBeamEnergy)
        }
        if criteria.trackBeamCurrent {
            columns.append(keyColumnBeamCurrent)
        }
        if criteria.trackBeamBackground {
            columns.append(keyColumnBeamBackground)
        }
        if criteria.trackBeamIntegral {
            columns.append(keyColumnBeamIntegral)
        }
        
        let headers = setupHeaders(columns)
        logger.writeLineOfFields(headers, destination: .results)
        logger.finishLine(.results) // +1 line padding
    }
    
    fileprivate func setupHeaders(_ headers: [String]) -> [AnyObject] {
        let firstFront = criteria.startParticleType.symbol()
        let firstBack = firstFront
        let wellBack = SearchType.alpha.symbol()
        // TODO: criteria.next all symbols handling
        let secondFront = "A"
        let secondBack = "A"
        let dict = ["$": firstFront,
                    "@": firstBack,
                    "*": wellBack,
                    "&": secondFront,
                    "^": secondBack]
        return headers.map { (s: String) -> String in
            var result = s
            for (key, value) in dict {
                result = result.replacingOccurrences(of: key, with: value)
            }
            return result
        } as [AnyObject]
    }
    
    fileprivate var currentStartEventNumber: CUnsignedLongLong?
    
    fileprivate func gammaAt(row: Int) -> DetectorMatch? {
        return delegate.focalGammaContainer()?.itemAt(index: row)?.subMatches?[.gamma] ?? nil
    }
    
    func logGamma(GeOnly: Bool) {
        if !criteria.simplifyGamma, let f = delegate.focalGammaContainer() {
            let count = f.count
            if count > 0 {
                for i in 0...count-1 {
                    if let item = f.itemAt(index: i), let gamma = item.subMatches?[.gamma], var g = gamma {
                        let destination: LoggerDestination = GeOnly ? .gammaGeOnly : .gammaAll
                        let c = g.count
                        if c > 0 {
                            let rowsMax = c
                            for row in 0 ..< rowsMax {
                                for column in columnsGamma {
                                    var field = ""
                                    switch column {
                                    case keyColumnEvent:
                                        if row == 0, let eventNumber = item.eventNumber {
                                            field = delegate.currentFileEventNumber(eventNumber)
                                        }
                                    case keyColumnGammaEnergy(false):
                                        if let energy = g.itemAt(index: row)?.energy {
                                            field = String(format: "%.7f", energy)
                                        }
                                    case keyColumnGammaSumEnergy:
                                        if row == 0, let sum = g.getSumEnergy() {
                                            field = String(format: "%.7f", sum)
                                        }
                                    case keyColumnGammaEncoder(false):
                                        if let encoder = g.itemAt(index: row)?.encoder {
                                            field = String(format: "%hu", encoder)
                                        }
                                    case keyColumnGammaStrip(false):
                                        // TODO: !!!
                                        field = ""
//                                        if let strip = g.itemAt(index: row)?.strip0_15 {
//                                            field = String(format: "%hu", strip)
//                                        }
                                    case keyColumnGammaDeltaTime(false):
                                        if let deltaTime = g.itemAt(index: row)?.deltaTime?.toMks() {
                                            field = String(format: "%lld", deltaTime)
                                        }
                                    case keyColumnGammaOverflow(false):
                                        if let overflow = g.itemAt(index: row)?.overflow {
                                            field = String(format: "%hu", overflow)
                                        }
                                    case keyColumnGammaCount:
                                        if row == 0 {
                                            field = String(format: "%d", c)
                                        }
                                    default:
                                        break
                                    }
                                    logger.writeField(field as AnyObject, destination: destination)
                                }
                                logger.finishLine(destination)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func logActResults() {
        let rowsMax = delegate.rowsCountForCurrentResult()
        for row in 0 ..< rowsMax {
            for column in columns {
                var field = ""
                switch column {
                case keyColumnRecoilFrontEvent:
                    if let eventNumber = delegate.fissionsAlphaWellAt(side: .front, index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnRecoilFrontEnergy:
                    if let energy = delegate.fissionsAlphaWellAt(side: .front, index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnRecoilFrontOverflow:
                    if let overflow = delegate.fissionsAlphaWellAt(side: .front, index: row)?.overflow {
                        field = String(format: "%hu", overflow)
                    }
                case keyColumnRecoilFrontDeltaTime(log: false), keyColumnRecoilFrontDeltaTime(log: true):
                    if let deltaTime = delegate.fissionsAlphaWellAt(side: .front, index: row)?.deltaTime?.toMks() {
                        if column == keyColumnRecoilFrontDeltaTime(log: false) {
                            field = String(format: "%lld", abs(deltaTime))
                        } else {
                            field = String(format: "%.7f", log2(abs(Float(deltaTime))))
                        }
                    }
                case keyColumnRecoilBackEvent:
                    if let eventNumber = delegate.fissionsAlphaWellAt(side: .back, index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnRecoilBackEnergy:
                    if let energy = delegate.fissionsAlphaWellAt(side: .back, index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartEvent:
                    if let eventNumber = delegate.firstParticleAt(side: .front).itemAt(index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                        currentStartEventNumber = eventNumber
                    } else if row < delegate.neutronsCountWithNewLine(), let eventNumber = currentStartEventNumber { // Need track start event number for neutron times results
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnStartFrontSum:
                    if row == 0, let sum = delegate.firstParticleAt(side: .front).getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnStartFrontEnergy:
                    if let energy = delegate.firstParticleAt(side: .front).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartFrontOverflow:
                    if let overflow = delegate.firstParticleAt(side: .front).itemAt(index: row)?.overflow {
                        field = String(format: "%hu", overflow)
                    }
                case keyColumnStartFrontDeltaTime:
                    if let deltaTime = delegate.firstParticleAt(side: .front).itemAt(index: row)?.deltaTime?.toMks() {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartFrontStrip:
                    if let strip = delegate.firstParticleAt(side: .front).itemAt(index: row)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnStartFocal(position: .X), keyColumnStartFocal(position: .Y), keyColumnStartFocal(position: .Z):
                    var p: Position
                    switch column {
                    case keyColumnStartFocal(position: .X):
                        p = .X
                    case keyColumnStartFocal(position: .Y):
                        p = .Y
                    default:
                        p = .Z
                    }
                    if let s = firstParticleFocal(position: p, row: row) {
                        field = s
                    }
                case keyColumnStartBackSum:
                    if row == 0, let sum = delegate.firstParticleAt(side: .back).getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnStartBackEnergy:
                    if let energy = delegate.firstParticleAt(side: .back).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartBackOverflow:
                    if let overflow = delegate.firstParticleAt(side: .back).itemAt(index: row)?.overflow {
                        field = String(format: "%hu", overflow)
                    }
                case keyColumnStartBackDeltaTime:
                    if let deltaTime = delegate.firstParticleAt(side: .back).itemAt(index: row)?.deltaTime?.toMks() {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartBackStrip:
                    if let strip = delegate.firstParticleAt(side: .back).itemAt(index: row)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnWellEnergy:
                    if let energy = delegate.fissionsAlphaWellAt(side: .front, index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnWellOverflow:
                    if let overflow = delegate.fissionsAlphaWellAt(side: .front, index: row)?.overflow {
                        field = String(format: "%hu", overflow)
                    }
                case keyColumnWellPosition:
                    if let item = delegate.fissionsAlphaWellAt(side: .front, index: row), let strip1_N = item.strip1_N, let encoder = item.encoder {
                        field = String(format: "FWell%d.%d", encoder, strip1_N)
                    }
                case keyColumnWellDetector:
                    if let item = delegate.fissionsAlphaWellAt(side: .front, index: row), let encoder = item.encoder {
                        let detector = delegate.wellDetectorNumber(Int(encoder), stripsSide: .front)
                        field = String(format: "%d", detector)
                    }
                case keyColumnWell(position: .X), keyColumnWell(position: .Y), keyColumnWell(position: .Z):
                    var p: Position
                    switch column {
                    case keyColumnWell(position: .X):
                        p = .X
                    case keyColumnWell(position: .Y):
                        p = .Y
                    default:
                        p = .Z
                    }
                    if let s = well(position: p, row: row) {
                        field = s
                    }
                case keyColumnWellAngle, keyColumnWellRangeInDeadLayers:
                    if let angle = wellAngle(row: row) {
                        if column == keyColumnWellAngle {
                            field = String(format: "%.2f", angle)
                        } else {
                            // TODO: !!!
//                            let range = StripDetector.side.deadLayer()/sin(angle * CGFloat.pi / 180) + StripDetector.focal.deadLayer()/sin((90 - angle) * CGFloat.pi / 180)
//                            field = String(format: "%.5f", range)
                        }
                    }
                case keyColumnWellStrip:
                    if let encoder = delegate.fissionsAlphaWellAt(side: .front, index: row)?.encoder {
//                    if let strip = delegate.fissionsAlphaWellAt(side: .front, index: row)?.strip1_N {
                        field = String(format: "%d", encoder)
                    }
                case keyColumnWellBackEnergy:
                    if let energy = delegate.fissionsAlphaWellAt(side: .back, index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnWellBackOverflow:
                    if let overflow = delegate.fissionsAlphaWellAt(side: .back, index: row)?.overflow {
                        field = String(format: "%hu", overflow)
                    }
                case keyColumnWellBackPosition:
                    if let item = delegate.fissionsAlphaWellAt(side: .back, index: row), let strip1_N = item.strip1_N, let encoder = item.encoder {
                        field = String(format: "FWellBack%d.%d", encoder, strip1_N)
                    }
                case keyColumnWellBackStrip:
                    if let encoder = delegate.fissionsAlphaWellAt(side: .back, index: row)?.encoder {
//                    if let strip = delegate.fissionsAlphaWellAt(side: .back, index: row)?.strip1_N {
                        field = String(format: "%d", encoder)
                    }
                case keyColumnTKEFront:
                    if let s = TKE(row: row, side: .front) {
                        field = s
                    }
                case keyColumnTKEBack:
                    if let s = TKE(row: row, side: .back) {
                        field = s
                    }
                case keyColumnNeutronsAverageTime:
                    if row == 0 {
                        let neutrons = delegate.neutrons()
                        let average = neutrons.averageTime.toMks()
                        if average > 0 {
                            field = String(format: "%.1f", average)
                        } else {
                            field = "0"
                        }
                    }
                case keyColumnNeutronTime:
                    if row > 0 { // skip new line
                        let neutrons = delegate.neutrons()
                        let index = row - 1
                        let times = neutrons.times
                        if index < times.count {
                            field = String(format: "%.1f", times[index].toMks())
                        }
                    }
                case keyColumnNeutronCounter, keyColumnNeutronBlock, keyColumnNeutronCounterX, keyColumnNeutronCounterY, keyColumnNeutronAngle, keyColumnNeutronRelatedFissionBack:
                    if row > 0 {
                        let neutrons = delegate.neutrons()
                        let index = row - 1
                        if column == keyColumnNeutronBlock {
                            let encoders = neutrons.encoders
                            if index < encoders.count {
                                field = String(format: "%hu", encoders[index])
                            }
                        } else {
                            let counters = neutrons.counters
                            if index < counters.count {
                                let counterIndex = counters[index]
                                if column == keyColumnNeutronCounter {
                                    field = String(format: "%d", counterIndex)
                                } else if let point = NeutronDetector.pointFor(counter: counterIndex) {
                                    if column == keyColumnNeutronAngle || column == keyColumnNeutronRelatedFissionBack {
                                        // TODO: revision of this logic, pointForWell(row: 0)
                                        if let pointFront = pointForFirstParticleFocal(row: 0), let pointSide = pointForWell(row: 0) {
                                            let angle = NeutronDetector.angle(neutronPoint: point, focalFragmentPoint: pointFront, sideFragmentPoint: pointSide)
                                            if column == keyColumnNeutronAngle {
                                                field = String(format: "%.2f", angle)
                                            } else {
                                                if let energy = (angle < 0 ? delegate.fissionsAlphaWellAt(side: .back, index: 0) : delegate.firstParticleAt(side: .back).itemAt(index: 0))?.energy {
                                                    field = String(format: "%.7f", energy)
                                                }
                                            }
                                        }
                                    } else {
                                        field = String(format: "%.3f", column == keyColumnNeutronCounterX ? point.x : point.y)
                                    }
                                }
                            }
                        }
                    }
                case keyColumnNeutrons:
                    if row == 0 {
                        let neutrons = delegate.neutrons()
                        field = String(format: "%llu", neutrons.count)
                    }
                case keyColumnGammaEnergy(true):
                    if let energy = gammaAt(row: row)?.itemWithMaxEnergy()?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnGammaSumEnergy:
                    if row == 0, let sum = gammaAt(row: row)?.getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnGammaEncoder(true):
                    if let encoder = gammaAt(row: row)?.itemWithMaxEnergy()?.encoder {
                        field = String(format: "%hu", encoder)
                    }
                case keyColumnGammaStrip(true):
                    // TODO: !!!
                    field = ""
//                    if let strip = gammaAt(row: row)?.itemWithMaxEnergy()?.strip0_15 {
//                        field = String(format: "%hu", strip)
//                    }
                case keyColumnGammaDeltaTime(true):
                    if let deltaTime = gammaAt(row: row)?.itemWithMaxEnergy()?.deltaTime?.toMks() {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnGammaCount:
                    if let count = gammaAt(row: row)?.count {
                        field = String(format: "%d", count)
                    }
                case keyColumnBeamEnergy:
                    if row == 0 {
                        if let e = delegate.beamState().energy {
                            field = String(format: "%.1f", Float(e.energy) / 10.0)
                        }
                    }
                case keyColumnBeamCurrent:
                    if row == 0 {
                        if let e = delegate.beamState().current {
                            field = String(format: "%.2f", Float(e.energy) / 1000.0)
                        }
                    }
                case keyColumnBeamBackground:
                    if row == 0 {
                        if let e = delegate.beamState().background {
                            field = String(format: "%.1f", Float(e.energy))
                        }
                    }
                case keyColumnBeamIntegral:
                    if row == 0 {
                        if let e = delegate.beamState().integral {
                            field = String(format: "%.1f", Float(e.energy) * 10.0)
                        }
                    }
                default:
                    break
                }
                logger.writeField(field as AnyObject, destination: .results)
            }
            logger.finishLine(.results)
        }
    }
    
    fileprivate func TKE(row: Int, side: StripsSide) -> String? {
        if row == 0, let focal = delegate.firstParticleAt(side: side).itemAt(index: row)?.energy, let side = delegate.fissionsAlphaWellAt(side: side, index: 0)?.energy {
            return String(format: "%.7f", focal + side)
        } else {
            return nil
        }
    }
    
    fileprivate func pointForFirstParticleFocal(row: Int) -> PointXYZ? {
//        if let itemFront = delegate.firstParticleAt(side: .front).itemAt(index: row), let stripFront1_N = itemFront.strip1_N, let itemBack = delegate.firstParticleAt(side: .back).itemAt(index: row), let stripBack1_N = itemBack.strip1_N {
//            let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0_N: stripFront1_N - 1, stripBack0_N: stripBack1_N - 1)
//            return point
//        } else {
        return nil
//        }
    }
    
    fileprivate func firstParticleFocal(position: Position, row: Int) -> String? {
        if let point = pointForFirstParticleFocal(row: row) {
            return String(format: "%.1f", position.relatedCoordinate(point: point))
        } else {
            return nil
        }
    }
    
    fileprivate func pointForWell(row: Int) -> PointXYZ? {
        if let itemFront = delegate.fissionsAlphaWellAt(side: .front, index: row), let stripFront1_N = itemFront.strip1_N, let itemBack = delegate.fissionsAlphaWellAt(side: .back, index: row), let stripBack1_N = itemBack.strip1_N, let encoder = itemFront.encoder {
            let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .side, stripFront0_N: stripFront1_N - 1, stripBack0_N: stripBack1_N - 1, encoderSide: Int(encoder))
            return point
        } else {
            return nil
        }
    }
    
    fileprivate func well(position: Position, row: Int) -> String? {
        if let point = pointForWell(row: row) {
            return String(format: "%.1f", position.relatedCoordinate(point: point))
        } else {
            return nil
        }
    }
    
    func wellAngle(row: Int) -> CGFloat? {
        if let itemFocalFront = delegate.firstParticleAt(side: .front).itemAt(index: 0), let stripFocalFront1_N = itemFocalFront.strip1_N, let itemFocalBack = delegate.firstParticleAt(side: .back).itemAt(index: 0), let stripFocalBack1_N = itemFocalBack.strip1_N, let itemSideFront = delegate.fissionsAlphaWellAt(side: .front, index: row), let stripSideFront1_N = itemSideFront.strip1_N, let itemSideBack = delegate.fissionsAlphaWellAt(side: .back, index: row), let stripSideBack1_N = itemSideBack.strip1_N, let encoderSide = itemSideFront.encoder {
            // TODO: !!!
            let pointFront: PointXYZ? = nil//DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0_N: stripFocalFront1_N - 1, stripBack0_N: stripFocalBack1_N - 1)
            let pointSide = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .side, stripFront0_N: stripSideFront1_N - 1, stripBack0_N: stripSideBack1_N - 1, encoderSide: Int(encoderSide))
            let angle = pointFront?.angleFrom(point: pointSide)
            return angle
        } else {
            return nil
        }
    }
    
//    fileprivate func fissionAlpha(_ index: Int, row: Int, side: StripsSide) -> DetectorMatchItem? {
//        return delegate.nextParticleAt(side: side, index: index)?.itemAt(index: row)
//    }
//
//    fileprivate func fissionAlphaSum(_ index: Int, row: Int, side: StripsSide) -> String {
//        if row == 0, let sum = delegate.nextParticleAt(side: side, index: index)?.getSumEnergy() {
//            return String(format: "%.7f", sum)
//        } else {
//            return ""
//        }
//    }
    
//    fileprivate func fissionAlphaEventNumber(_ index: Int, row: Int, side: StripsSide) -> String {
//        if let eventNumber = fissionAlpha(index, row: row, side: side)?.eventNumber {
//            return delegate.currentFileEventNumber(eventNumber)
//        }
//        return ""
//    }
//
//    fileprivate func fissionAlphaEnergy(_ index: Int, row: Int, side: StripsSide) -> String {
//        if let energy = fissionAlpha(index, row: row, side: side)?.energy {
//            return String(format: "%.7f", energy)
//        }
//        return ""
//    }
//
//    fileprivate func fissionAlphaOverflow(_ index: Int, row: Int, side: StripsSide) -> String {
//        if let overflow = fissionAlpha(index, row: row, side: side)?.overflow {
//            return String(format: "%hu", overflow)
//        }
//        return ""
//    }
//
//    fileprivate func fissionAlphaDeltaTime(_ index: Int, row: Int, side: StripsSide) -> String {
//        if let deltaTime = fissionAlpha(index, row: row, side: side)?.deltaTime?.toMks() {
//            return String(format: "%lld", deltaTime)
//        }
//        return ""
//    }
//
//    fileprivate func fissionAlphaStrip(_ index: Int, row: Int, side: StripsSide) -> String {
//        if let strip = fissionAlpha(index, row: row, side: side)?.strip1_N {
//            return String(format: "%d", strip)
//        }
//        return ""
//    }
    
}
