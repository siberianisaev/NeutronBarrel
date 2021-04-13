//
//  ResultsTable.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 12.03.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Foundation

protocol ResultsTableDelegate: class {
    
    func rowsCountForCurrentResult() -> Int
    func neutronsCountWithNewLine() -> Int
    func neutrons() -> NeutronsMatch
    func currentFileEventNumber(_ number: CUnsignedLongLong) -> String
    func focalGammaContainer() -> DetectorMatch?
    func vetoAt(index: Int) -> DetectorMatchItem?
    func recoilAt(side: StripsSide, index: Int) -> DetectorMatchItem?
    func fissionsAlphaWellAt(side: StripsSide, index: Int) -> DetectorMatchItem?
    func beamState() -> BeamState
    func firstParticleAt(side: StripsSide) -> DetectorMatch
    func nextParticleAt(side: StripsSide, index: Int) -> DetectorMatch?
    func specialWith(eventId: Int) -> CUnsignedShort?
    
}

class ResultsTable {
    
    // TODO: position code refactoring
    enum Position: String {
        case X = "X", Y = "Y", Z = "Z"
        
        func relatedCoordinate(point: (x: CGFloat, y: CGFloat, z: CGFloat)) -> CGFloat {
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
    
    fileprivate func searchExtraPostfix(_ s: String) -> String {
        if criteria.searchExtraFromLastParticle {
            return s + "(\(criteria.nextMaxIndex() ?? 0))"
        } else {
            return s
        }
    }
    
    fileprivate var columns = [String]()
    fileprivate var keyColumnRecoilFrontEvent: String {
        let name = criteria.recoilType == .recoil ? "Recoil" : "Heavy Recoil"
        return "Event(\(name))"
    }
    fileprivate var keyRecoil: String {
        return  criteria.recoilType == .recoil ? "R" : "HR"
    }
    fileprivate var keyColumnRecoilFrontEnergy: String {
        return "E(\(keyRecoil)Fron)"
    }
    fileprivate var keyColumnRecoilFrontFrontMarker: String {
        return "\(keyRecoil)FronMarker"
    }
    fileprivate var keyColumnRecoilFrontDeltaTime: String {
        return "dT(\(keyRecoil)Fron-$Fron)"
    }
    fileprivate var keyColumnRecoilBackEvent: String {
        let name = criteria.recoilBackType == .recoil ? "Recoil" : "Heavy Recoil"
        return "Event(\(name)Back)"
    }
    fileprivate let keyColumnRecoilBackEnergy: String = "E(RBack)"
    fileprivate var keyColumnTof = "TOF"
    fileprivate var keyColumnTof2 = "TOF2"
    fileprivate var keyColumnTofDeltaTime = "dT(TOF-RFron)"
    fileprivate var keyColumnTof2DeltaTime = "dT(TOF2-RFron)"
    fileprivate var keyColumnStartEvent = "Event($)"
    fileprivate var keyColumnStartFrontSum = "Sum($Fron)"
    fileprivate var keyColumnStartFrontEnergy = "$Fron"
    fileprivate var keyColumnStartFrontMarker = "$FronMarker"
    fileprivate var keyColumnStartFrontDeltaTime = "dT($FronFirst-Next)"
    fileprivate var keyColumnStartFrontStrip = "Strip($Fron)"
    fileprivate func keyColumnStartFocal(position: Position) -> String {
        return "StartFocalPosition\(position.rawValue)"
    }
    fileprivate var keyColumnStartBackSum = "Sum(@Back)"
    fileprivate var keyColumnStartBackEnergy = "@Back"
    fileprivate var keyColumnStartBackMarker = "@BackMarker"
    fileprivate var keyColumnStartBackDeltaTime = "dT($Fron-@Back)"
    fileprivate var keyColumnStartBackStrip = "Strip(@Back)"
    fileprivate var keyColumnWellEnergy: String {
        return searchExtraPostfix("$Well")
    }
    fileprivate var keyColumnWellMarker = "$WellMarker"
    fileprivate var keyColumnWellPosition = "$WellPos"
    fileprivate func keyColumnWell(position: Position) -> String {
        return "$WellPos\(position.rawValue)"
    }
    fileprivate var keyColumnWellAngle = "$WellAngle"
    fileprivate var keyColumnWellStrip = "Strip($Well)"
    fileprivate var keyColumnWellBackEnergy = "*WellBack"
    fileprivate var keyColumnWellBackMarker = "*WellBackMarker"
    fileprivate var keyColumnWellBackPosition = "*WellBackPos"
    fileprivate var keyColumnWellBackStrip = "Strip(*WellBack)"
    fileprivate var keyColumnNeutronsAverageTime = "NeutronsAverageTime"
    fileprivate var keyColumnNeutronTime = "NeutronTime"
    fileprivate var keyColumnNeutronCounter = "NeutronCounter"
    fileprivate var keyColumnNeutrons: String {
        return searchExtraPostfix("Neutrons")
    }
    fileprivate var keyColumnNeutrons_N = "N1...N4"
    fileprivate let keyColumnEvent: String = "Event"
    fileprivate func keyColumnGammaEnergy(_ max: Bool) -> String {
        var s = searchExtraPostfix("Gamma")
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
    fileprivate func keyColumnGammaDeltaTime(_ max: Bool) -> String {
        var s = "dT($Fron-Gamma"
        if max {
            s += "Max"
        }
        return s + ")"
    }
    fileprivate func keyColumnGammaMarker(_ max: Bool) -> String {
        var s = "Gamma"
        if max {
            s += "Max"
        }
        return s + "Marker"
    }
    fileprivate var keyColumnGammaCount = "GammaCount"
    fileprivate var keyColumnGammaSumEnergy = "GammaSumEnergy"
    fileprivate var keyColumnSpecial = "Special"
    fileprivate func keyColumnSpecialFor(eventId: Int) -> String {
        return keyColumnSpecial + String(eventId)
    }
    fileprivate var keyColumnBeamEnergy = "BeamEnergy"
    fileprivate var keyColumnBeamCurrent = "BeamCurrent"
    fileprivate var keyColumnBeamBackground = "BeamBackground"
    fileprivate var keyColumnBeamIntegral = "BeamIntegral"
    fileprivate var keyColumnVetoEvent = "Event(VETO)"
    fileprivate var keyColumnVetoEnergy = "E(VETO)"
    fileprivate var keyColumnVetoStrip = "Strip(VETO)"
    fileprivate var keyColumnVetoDeltaTime = "dT($Fron-VETO)"
    fileprivate func keyColumnFissionAlphaFrontSum(_ index: Int) -> String {
        return "Sum(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontEvent(_ index: Int) -> String {
        return "Event(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontEnergy(_ index: Int) -> String {
        return "E(&Front\(index))"
    }
    fileprivate func keyColumnFissionAlphaFrontMarker(_ index: Int) -> String {
        return "&Front\(index)Marker"
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
    fileprivate func keyColumnFissionAlphaBackMarker(_ index: Int) -> String {
        return "^Back\(index)Marker"
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
                keyColumnGammaDeltaTime(false),
                keyColumnGammaMarker(false),
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
        if !criteria.startFromRecoil() {
            columns.append(contentsOf: [
                keyColumnRecoilFrontEvent,
                keyColumnRecoilFrontEnergy,
                keyColumnRecoilFrontFrontMarker,
                keyColumnRecoilFrontDeltaTime,
                keyColumnRecoilBackEvent,
                keyColumnRecoilBackEnergy
            ])
        }
        columns.append(contentsOf: [
            keyColumnTof,
            keyColumnTofDeltaTime
        ])
        if criteria.useTOF2 {
            columns.append(contentsOf: [
                keyColumnTof2,
                keyColumnTof2DeltaTime,
            ])
        }
        columns.append(contentsOf: [
            keyColumnStartEvent,
            keyColumnStartFrontSum,
            keyColumnStartFrontEnergy,
            keyColumnStartFrontMarker,
            keyColumnStartFrontDeltaTime,
            keyColumnStartFrontStrip
        ])
        columns.append(contentsOf: ([.X, .Y, .Z] as [Position]).map { keyColumnStartFocal(position: $0) })
        columns.append(contentsOf: [
            keyColumnStartBackSum,
            keyColumnStartBackEnergy,
            keyColumnStartBackMarker,
            keyColumnStartBackDeltaTime,
            keyColumnStartBackStrip
        ])
        if criteria.searchWell {
            columns.append(contentsOf: [
                keyColumnWellEnergy,
                keyColumnWellMarker,
                keyColumnWellPosition
                ])
            columns.append(contentsOf: ([.X, .Y, .Z] as [Position]).map { keyColumnWell(position: $0) })
            columns.append(contentsOf: [
                keyColumnWellAngle,
                keyColumnWellStrip,
                keyColumnWellBackEnergy,
                keyColumnWellBackMarker,
                keyColumnWellBackPosition,
                keyColumnWellBackStrip
                ])
        }
        if criteria.searchNeutrons {
            columns.append(contentsOf: [keyColumnNeutronsAverageTime, keyColumnNeutronTime, keyColumnNeutronCounter, keyColumnNeutrons])
            if dataProtocol.hasNeutrons_N() {
                columns.append(keyColumnNeutrons_N)
            }
        }
        columns.append(contentsOf: [
            keyColumnGammaEnergy(true),
            keyColumnGammaSumEnergy,
            keyColumnGammaEncoder(true),
            keyColumnGammaDeltaTime(true),
            keyColumnGammaCount
            ])
        if criteria.searchSpecialEvents {
            let values = criteria.specialEventIds.map({ (i: Int) -> String in
                return keyColumnSpecialFor(eventId: i)
            })
            columns.append(contentsOf: values)
        }
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
        if criteria.searchVETO {
            columns.append(contentsOf: [
                keyColumnVetoEvent,
                keyColumnVetoEnergy,
                keyColumnVetoStrip,
                keyColumnVetoDeltaTime
                ])
        }
        if let c2 = criteria.next[2] {
            columns.append(keyColumnFissionAlphaFrontEvent(2))
            if c2.summarizeFront {
                columns.append(keyColumnFissionAlphaFrontSum(2))
            }
            columns.append(contentsOf: [
                keyColumnFissionAlphaFrontEnergy(2),
                keyColumnFissionAlphaFrontMarker(2),
                keyColumnFissionAlphaFrontDeltaTime(2),
                keyColumnFissionAlphaFrontStrip(2),
                keyColumnFissionAlphaBackSum(2),
                keyColumnFissionAlphaBackEnergy(2),
                keyColumnFissionAlphaBackMarker(2),
                keyColumnFissionAlphaBackDeltaTime(2),
                keyColumnFissionAlphaBackStrip(2)
                ])
            if let c3 = criteria.next[3]  {
                columns.append(keyColumnFissionAlphaFrontEvent(3))
                if c3.summarizeFront {
                    columns.append(keyColumnFissionAlphaFrontSum(3))
                }
                columns.append(contentsOf: [
                    keyColumnFissionAlphaFrontEnergy(3),
                    keyColumnFissionAlphaFrontMarker(3),
                    keyColumnFissionAlphaFrontDeltaTime(3),
                    keyColumnFissionAlphaFrontStrip(3),
                    keyColumnFissionAlphaBackSum(3),
                    keyColumnFissionAlphaBackEnergy(3),
                    keyColumnFissionAlphaBackMarker(3),
                    keyColumnFissionAlphaBackDeltaTime(3),
                    keyColumnFissionAlphaBackStrip(3)
                    ])
            }
        }
        let headers = setupHeaders(columns)
        logger.writeLineOfFields(headers, destination: .results)
        logger.finishLine(.results) // +1 line padding
    }
    
    fileprivate func setupHeaders(_ headers: [String]) -> [AnyObject] {
        let firstFront = criteria.startParticleType.symbol()
        let firstBack = criteria.startParticleBackType.symbol()
        let wellBack = criteria.wellParticleBackType.symbol()
        // TODO: criteria.next all symbols handling
        let last = criteria.next[criteria.nextMaxIndex() ?? -1]
        let secondFront = last?.frontType.symbol() ?? ""
        let secondBack = last?.backType.symbol() ?? ""
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
    
    fileprivate func firstTOF(row: Int, type: SearchType) -> DetectorMatchItem? {
        return delegate.recoilAt(side: .front, index: row)?.subMatches?[type]??.itemAt(index: 0) ?? nil
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
                        if GeOnly {
                            g = g.filteredByMarker(marker: 0)
                        }
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
                                    case keyColumnGammaDeltaTime(false):
                                        if let deltaTime = g.itemAt(index: row)?.deltaTime {
                                            field = String(format: "%lld", deltaTime)
                                        }
                                    case keyColumnGammaMarker(false):
                                        if let marker = g.itemAt(index: row)?.marker {
                                            field = String(format: "%hu", marker)
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
                    if let eventNumber = delegate.recoilAt(side: .front, index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnRecoilFrontEnergy:
                    if let energy = delegate.recoilAt(side: .front, index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnRecoilFrontFrontMarker:
                    if let marker = delegate.recoilAt(side: .front, index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnRecoilFrontDeltaTime:
                    if let deltaTime = delegate.recoilAt(side: .front, index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnRecoilBackEvent:
                    if let eventNumber = delegate.recoilAt(side: .back, index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnRecoilBackEnergy:
                    if let energy = delegate.recoilAt(side: .back, index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnTof, keyColumnTof2:
                    if let value = firstTOF(row: row, type: column == keyColumnTof ? .tof : .tof2)?.value {
                        let format = "%." + (criteria.unitsTOF == .channels ? "0" : "7") + "f"
                        field = String(format: format, value)
                    }
                case keyColumnTofDeltaTime, keyColumnTof2DeltaTime:
                    if let deltaTime = firstTOF(row: row, type: column == keyColumnTofDeltaTime ? .tof : .tof2)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartEvent:
                    if let eventNumber = delegate.firstParticleAt(side: .front).itemAt(index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                        currentStartEventNumber = eventNumber
                    } else if row < delegate.neutronsCountWithNewLine(), let eventNumber = currentStartEventNumber { // Need track start event number for neutron times results
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnStartFrontSum:
                    if row == 0, !criteria.startFromRecoil(), let sum = delegate.firstParticleAt(side: .front).getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnStartFrontEnergy:
                    if let energy = delegate.firstParticleAt(side: .front).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartFrontMarker:
                    if let marker = delegate.firstParticleAt(side: .front).itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnStartFrontDeltaTime:
                    if let deltaTime = delegate.firstParticleAt(side: .front).itemAt(index: row)?.deltaTime {
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
                    if row == 0, !criteria.startFromRecoil(), let sum = delegate.firstParticleAt(side: .back).getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnStartBackEnergy:
                    if let energy = delegate.firstParticleAt(side: .back).itemAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnStartBackMarker:
                    if let marker = delegate.firstParticleAt(side: .back).itemAt(index: row)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnStartBackDeltaTime:
                    if let deltaTime = delegate.firstParticleAt(side: .back).itemAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnStartBackStrip:
                    if let strip = delegate.firstParticleAt(side: .back).itemAt(index: row)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnWellEnergy:
                    if row == 0, let energy = delegate.fissionsAlphaWellAt(side: .front, index: 0)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnWellMarker:
                    if row == 0, let marker = delegate.fissionsAlphaWellAt(side: .front, index: 0)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnWellPosition:
                    if row == 0, let item = delegate.fissionsAlphaWellAt(side: .front, index: 0), let strip0_15 = item.strip0_15, let encoder = item.encoder {
                        field = String(format: "FWell%d.%d", encoder, strip0_15 + 1)
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
                case keyColumnWellAngle:
                    if row == 0, let itemFocalFront = delegate.firstParticleAt(side: .front).itemAt(index: row), let stripFocalFront1 = itemFocalFront.strip1_N, let itemFocalBack = delegate.firstParticleAt(side: .back).itemAt(index: row), let stripFocalBack1 = itemFocalBack.strip1_N, let itemSideFront = delegate.fissionsAlphaWellAt(side: .front, index: 0), let stripSideFront0 = itemSideFront.strip0_15, let itemSideBack = delegate.fissionsAlphaWellAt(side: .back, index: 0), let stripSideBack0 = itemSideBack.strip0_15, let encoderSide = itemSideFront.encoder {
                        let pointFront = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0: stripFocalFront1 - 1, stripBack0: stripFocalBack1 - 1)
                        let pointSide = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .side, stripFront0: Int(stripSideFront0), stripBack0: Int(stripSideBack0), encoderSide: Int(encoderSide))
                        let hypotenuse = sqrt(pow(pointFront.x - pointSide.x, 2) + pow(pointFront.y - pointSide.y, 2) + pow(pointFront.z - pointSide.z, 2))
                        let sinus = pointSide.z / hypotenuse
                        let arcsinus = asin(sinus) * 180 / CGFloat.pi
                        field = String(format: "%.2f", arcsinus)
                    }
                case keyColumnWellStrip:
                    if row == 0, let strip = delegate.fissionsAlphaWellAt(side: .front, index: 0)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnWellBackEnergy:
                    if row == 0, let energy = delegate.fissionsAlphaWellAt(side: .back, index: 0)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnWellBackMarker:
                    if row == 0, let marker = delegate.fissionsAlphaWellAt(side: .back, index: 0)?.marker {
                        field = String(format: "%hu", marker)
                    }
                case keyColumnWellBackPosition:
                    if row == 0, let item = delegate.fissionsAlphaWellAt(side: .back, index: 0), let strip0_15 = item.strip0_15, let encoder = item.encoder {
                        field = String(format: "FWellBack%d.%d", encoder, strip0_15 + 1)
                    }
                case keyColumnWellBackStrip:
                    if row == 0, let strip = delegate.fissionsAlphaWellAt(side: .back, index: 0)?.strip1_N {
                        field = String(format: "%d", strip)
                    }
                case keyColumnNeutronsAverageTime:
                    if row == 0 {
                        let average = delegate.neutrons().averageTime
                        if average > 0 {
                            field = String(format: "%.1f", average)
                        } else {
                            field = "0"
                        }
                    }
                case keyColumnNeutronTime:
                    if row > 0 { // skip new line
                        let index = row - 1
                        let times = delegate.neutrons().times
                        if index < times.count {
                            field = String(format: "%.1f", times[index])
                        }
                    }
                case keyColumnNeutronCounter:
                    if row > 0 {
                        let index = row - 1
                        let counters = delegate.neutrons().counters
                        if index < counters.count {
                            field = String(format: "%d", counters[index])
                        }
                    }
                case keyColumnNeutrons:
                    if row == 0 {
                        field = String(format: "%llu", delegate.neutrons().count)
                    }
                case keyColumnNeutrons_N:
                    if row == 0 {
                        field = String(format: "%llu", delegate.neutrons().NSum)
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
                case keyColumnGammaDeltaTime(true):
                    if let deltaTime = gammaAt(row: row)?.itemWithMaxEnergy()?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnGammaCount:
                    if let count = gammaAt(row: row)?.count {
                        field = String(format: "%d", count)
                    }
                case _ where column.hasPrefix(keyColumnSpecial):
                    if row == 0 {
                        if let eventId = Int(column.replacingOccurrences(of: keyColumnSpecial, with: "")), let v = delegate.specialWith(eventId: eventId) {
                            field = String(format: "%hu", v)
                        }
                    }
                case keyColumnBeamEnergy:
                    if row == 0 {
                        if let e = delegate.beamState().energy {
                            field = String(format: "%.1f", e.getFloatValue())
                        }
                    }
                case keyColumnBeamCurrent:
                    if row == 0 {
                        if let e = delegate.beamState().current {
                            field = String(format: "%.2f", e.getFloatValue())
                        }
                    }
                case keyColumnBeamBackground:
                    if row == 0 {
                        if let e = delegate.beamState().background {
                            field = String(format: "%.1f", e.getFloatValue())
                        }
                    }
                case keyColumnBeamIntegral:
                    if row == 0 {
                        if let e = delegate.beamState().integral {
                            field = String(format: "%.1f", e.getFloatValue())
                        }
                    }
                case keyColumnVetoEvent:
                    if let eventNumber = delegate.vetoAt(index: row)?.eventNumber {
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnVetoEnergy:
                    if let energy = delegate.vetoAt(index: row)?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnVetoStrip:
                    if let strip0_15 = delegate.vetoAt(index: row)?.strip0_15 {
                        field = String(format: "%hu", strip0_15 + 1)
                    }
                case keyColumnVetoDeltaTime:
                    if let deltaTime = delegate.vetoAt(index: row)?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnFissionAlphaFrontEvent(2), keyColumnFissionAlphaFrontEvent(3):
                    let index = column == keyColumnFissionAlphaFrontEvent(2) ? 2 : 3
                    field = fissionAlphaEventNumber(index, row: row, side: .front)
                case keyColumnFissionAlphaFrontSum(2), keyColumnFissionAlphaFrontSum(3):
                    let index = column == keyColumnFissionAlphaFrontSum(2) ? 2 : 3
                    field = fissionAlphaSum(index, row: row, side: .front)
                case keyColumnFissionAlphaFrontEnergy(2), keyColumnFissionAlphaFrontEnergy(3):
                    let index = column == keyColumnFissionAlphaFrontEnergy(2) ? 2 : 3
                    field = fissionAlphaEnergy(index, row: row, side: .front)
                case keyColumnFissionAlphaFrontMarker(2), keyColumnFissionAlphaFrontMarker(3):
                    let index = column == keyColumnFissionAlphaFrontMarker(2) ? 2 : 3
                    field = fissionAlphaMarker(index, row: row, side: .front)
                case keyColumnFissionAlphaFrontDeltaTime(2), keyColumnFissionAlphaFrontDeltaTime(3):
                    let index = column == keyColumnFissionAlphaFrontDeltaTime(2) ? 2 : 3
                    field = fissionAlphaDeltaTime(index, row: row, side: .front)
                case keyColumnFissionAlphaFrontStrip(2), keyColumnFissionAlphaFrontStrip(3):
                    let index = column == keyColumnFissionAlphaFrontStrip(2) ? 2 : 3
                    field = fissionAlphaStrip(index, row: row, side: .front)
                case keyColumnFissionAlphaBackSum(2), keyColumnFissionAlphaBackSum(3):
                    let index = column == keyColumnFissionAlphaBackSum(2) ? 2 : 3
                    field = fissionAlphaSum(index, row: row, side: .back)
                case keyColumnFissionAlphaBackEnergy(2), keyColumnFissionAlphaBackEnergy(3):
                    let index = column == keyColumnFissionAlphaBackEnergy(2) ? 2 : 3
                    field = fissionAlphaEnergy(index, row: row, side: .back)
                case keyColumnFissionAlphaBackMarker(2), keyColumnFissionAlphaBackMarker(3):
                    let index = column == keyColumnFissionAlphaBackMarker(2) ? 2 : 3
                    field = fissionAlphaMarker(index, row: row, side: .back)
                case keyColumnFissionAlphaBackDeltaTime(2), keyColumnFissionAlphaBackDeltaTime(3):
                    let index = column == keyColumnFissionAlphaBackDeltaTime(2) ? 2 : 3
                    field = fissionAlphaDeltaTime(index, row: row, side: .back)
                case keyColumnFissionAlphaBackStrip(2), keyColumnFissionAlphaBackStrip(3):
                    let index = column == keyColumnFissionAlphaBackStrip(2) ? 2 : 3
                    field = fissionAlphaStrip(index, row: row, side: .back)
                default:
                    break
                }
                logger.writeField(field as AnyObject, destination: .results)
            }
            logger.finishLine(.results)
        }
    }
    
    fileprivate func firstParticleFocal(position: Position, row: Int) -> String? {
        if let itemFront = delegate.firstParticleAt(side: .front).itemAt(index: row), let stripFront1 = itemFront.strip1_N, let itemBack = delegate.firstParticleAt(side: .back).itemAt(index: row), let stripBack1 = itemBack.strip1_N {
            let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .focal, stripFront0: stripFront1 - 1, stripBack0: stripBack1 - 1)
            return String(format: "%.1f", position.relatedCoordinate(point: point))
        } else {
            return nil
        }
    }
    
    fileprivate func well(position: Position, row: Int) -> String? {
        if row == 0, let itemFront = delegate.fissionsAlphaWellAt(side: .front, index: 0), let stripFront0 = itemFront.strip0_15, let itemBack = delegate.fissionsAlphaWellAt(side: .back, index: 0), let stripBack0 = itemBack.strip0_15, let encoder = itemFront.encoder {
            let point = DetectorsWellGeometry.coordinatesXYZ(stripDetector: .side, stripFront0: Int(stripFront0), stripBack0: Int(stripBack0), encoderSide: Int(encoder))
            return String(format: "%.1f", position.relatedCoordinate(point: point))
        } else {
            return nil
        }
    }
    
    fileprivate func fissionAlpha(_ index: Int, row: Int, side: StripsSide) -> DetectorMatchItem? {
        return delegate.nextParticleAt(side: side, index: index)?.itemAt(index: row)
    }
    
    fileprivate func fissionAlphaSum(_ index: Int, row: Int, side: StripsSide) -> String {
        if row == 0, let sum = delegate.nextParticleAt(side: side, index: index)?.getSumEnergy() {
            return String(format: "%.7f", sum)
        } else {
            return ""
        }
    }
    
    fileprivate func fissionAlphaEventNumber(_ index: Int, row: Int, side: StripsSide) -> String {
        if let eventNumber = fissionAlpha(index, row: row, side: side)?.eventNumber {
            return delegate.currentFileEventNumber(eventNumber)
        }
        return ""
    }
    
    fileprivate func fissionAlphaEnergy(_ index: Int, row: Int, side: StripsSide) -> String {
        if let energy = fissionAlpha(index, row: row, side: side)?.energy {
            return String(format: "%.7f", energy)
        }
        return ""
    }
    
    fileprivate func fissionAlphaMarker(_ index: Int, row: Int, side: StripsSide) -> String {
        if let marker = fissionAlpha(index, row: row, side: side)?.marker {
            return String(format: "%hu", marker)
        }
        return ""
    }
    
    fileprivate func fissionAlphaDeltaTime(_ index: Int, row: Int, side: StripsSide) -> String {
        if let deltaTime = fissionAlpha(index, row: row, side: side)?.deltaTime {
            return String(format: "%lld", deltaTime)
        }
        return ""
    }
    
    fileprivate func fissionAlphaStrip(_ index: Int, row: Int, side: StripsSide) -> String {
        if let strip = fissionAlpha(index, row: row, side: side)?.strip1_N {
            return String(format: "%d", strip)
        }
        return ""
    }
    
}
