//
//  ResultsTable.swift
//  NeutronsReader
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
    func gammaContainer() -> DetectorMatch?
    
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
    
    var neutronsPerEnergy = [Double: [Float]]()
    
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
    fileprivate var keyColumnNeutronsAverageTime = "NeutronsAverageTime"
    fileprivate var keyColumnNeutronTime = "NeutronTime"
    fileprivate var keyColumnNeutronCounter = "NeutronCounter"
    fileprivate var keyColumnNeutronBlock = "NeutronBlock"
    fileprivate var keyColumnNeutronCounterX = "NeutronCounterX"
    fileprivate var keyColumnNeutronCounterY = "NeutronCounterY"
    fileprivate var keyColumnNeutrons: String {
        return "Neutrons"
    }
    fileprivate let keyColumnEvent: String = "Event"
    fileprivate func keyColumnGammaEnergy() -> String {
        return "Gamma Energy"
    }
    fileprivate func keyColumnGammaEncoder() -> String {
        return "Gamma Encoder"
    }
    fileprivate func keyColumnGammaDeltaTime() -> String {
        return "Gamma dT"
    }
    fileprivate func keyColumnGammaMarker() -> String {
        return "Gamma Marker"
    }
    fileprivate var keyColumnGammaCount = "GammaCount"
    fileprivate var keyColumnGammaSumEnergy = "GammaSumEnergy"
    
    
    fileprivate var columnsGamma = [String]()
    
    func logGammaHeader() {
        columnsGamma.append(contentsOf: [
            keyColumnEvent,
            keyColumnGammaEnergy(),
            keyColumnGammaSumEnergy,
            keyColumnGammaEncoder(),
            keyColumnGammaDeltaTime(),
            keyColumnGammaMarker(),
            keyColumnGammaCount
        ])
        let headers = columnsGamma as [AnyObject]
        for destination in [.gammaAll, .gammaGeOnly] as [LoggerDestination] {
            logger.writeLineOfFields(headers, destination: destination)
            logger.finishLine(destination) // +1 line padding
        }
    }
    
    func logResultsHeader() {
        columns = []
        
        if !criteria.gammaStart {
            columns.append(keyColumnEvent)
        }
        columns.append(contentsOf: [keyColumnNeutronsAverageTime, keyColumnNeutronTime, keyColumnNeutronCounter, keyColumnNeutronBlock, keyColumnNeutrons])
        if criteria.neutronsPositions {
            columns.append(contentsOf: [keyColumnNeutronCounterX, keyColumnNeutronCounterY])
        }
        
        if criteria.gammaStart {
            columns.append(keyColumnEvent)
        }
        columns.append(contentsOf: [
            keyColumnGammaEnergy(),
            keyColumnGammaSumEnergy,
            keyColumnGammaEncoder(),
            keyColumnGammaDeltaTime(),
            keyColumnGammaCount
            ])
        
        let headers = columns as [AnyObject]
        logger.writeLineOfFields(headers, destination: .results)
        logger.finishLine(.results) // +1 line padding
    }
    
    fileprivate var currentStartEventNumber: CUnsignedLongLong?
    
    fileprivate func gammaAt(row: Int) -> DetectorMatch? {
        return delegate.gammaContainer()?.itemAt(index: row)?.subMatches?[.gamma] ?? nil
    }
    
    func logActResults() {
        let rowsMax = delegate.rowsCountForCurrentResult()
        for row in 0 ..< rowsMax {
            for column in columns {
                var field = ""
                switch column {
                case keyColumnEvent:
                    if let eventNumber = criteria.gammaStart ? delegate.gammaContainer()?.itemAt(index: 0)?.eventNumber : delegate.neutrons().eventNumbers.first {
                        field = delegate.currentFileEventNumber(eventNumber)
                    }
                case keyColumnNeutronsAverageTime:
                    if row == 0 {
                        let neutrons = delegate.neutrons()
                        let average = neutrons.averageTime
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
                            field = String(format: "%.1f", times[index])
                        }
                    }
                case keyColumnNeutronCounter, keyColumnNeutronBlock, keyColumnNeutronCounterX, keyColumnNeutronCounterY:
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
                                    field = String(format: "%.3f", column == keyColumnNeutronCounterX ? point.x : point.y)
                                }
                            }
                        }
                    }
                case keyColumnNeutrons:
                    if row == 0 {
                        let neutrons = delegate.neutrons()
                        field = String(format: "%llu", neutrons.count)
                    }
                case keyColumnGammaEnergy():
                    if let energy = gammaAt(row: row)?.itemWithMaxEnergy()?.energy {
                        field = String(format: "%.7f", energy)
                    }
                case keyColumnGammaSumEnergy:
                    if row == 0, let sum = gammaAt(row: row)?.getSumEnergy() {
                        field = String(format: "%.7f", sum)
                    }
                case keyColumnGammaEncoder():
                    if let encoder = gammaAt(row: row)?.itemWithMaxEnergy()?.encoder {
                        field = String(format: "%hu", encoder)
                    }
                case keyColumnGammaDeltaTime():
                    if let deltaTime = gammaAt(row: row)?.itemWithMaxEnergy()?.deltaTime {
                        field = String(format: "%lld", deltaTime)
                    }
                case keyColumnGammaCount:
                    if let count = gammaAt(row: row)?.count {
                        field = String(format: "%d", count)
                    }
                default:
                    break
                }
                logger.writeField(field as AnyObject, destination: .results)
            }
            logger.finishLine(.results)
        }
    }
    
}
