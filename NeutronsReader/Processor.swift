//
//  Processor.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 06.03.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Foundation

class Processor {
    
    var fissionFrontMinEnergy: Double = 0
    var recoilFrontMinEnergy: Double = 0
    var recoilFrontMaxEnergy: Double = 0
    var minTOFChannel: Double = 0
    var recoilMinTime: Double = 0
    var recoilMaxTime: Double = 0
    var recoilBackMaxTime: Double = 0
    var fissionMaxTime: Double = 0
    var maxTOFTime: Double = 0
    var maxGammaTime: Double = 0
    var maxNeutronTime: Double = 0
    var requiredFissionBack: Bool = false
    var requiredGamma: Bool = false
    var requiredTOF: Bool = false
    
    fileprivate var calibration = Calibration.defaultCalibration()
    fileprivate var selectedFiles = [String]()
    fileprivate var neutronsSummPerAct: Int = 0
    fileprivate var neutronsMultiplicityTotal = [Int: CUnsignedLongLong]()
    fileprivate var recoilsFrontPerAct = [AnyObject]()
    fileprivate var tofRealPerAct = [AnyObject]()
    fileprivate var fissionsFrontPerAct = [AnyObject]()
    fileprivate var fissionsBackPerAct = [AnyObject]()
    fileprivate var fissionsWelPerAct = [AnyObject]()
    fileprivate var gammaPerAct = [AnyObject]()
    fileprivate var tofGenerationsPerAct = [AnyObject]()
    fileprivate var fonPerAct: CUnsignedShort?
    fileprivate var recoilSpecialPerAct: CUnsignedShort?
    fileprivate var firstFissionInfo = [String: AnyObject]() // информация о главном осколке в цикле
    fileprivate var firstFissionTime: CUnsignedShort = 0 // время главного осколка в цикле
    fileprivate var isNewAct: Bool = false
    fileprivate var currentEventNumber: CUnsignedLongLong = 0
    fileprivate var mainCycleTimeEvent: Event?
    
    fileprivate var kEncoder: String {
        return "encoder"
    }
    fileprivate var kStrip0_15: String {
        return "strip_0_15"
    }
    fileprivate var kStrip1_48: String {
        return "strip_1_48"
    }
    fileprivate var kEnergy: String {
        return "energy"
    }
    fileprivate var kDeltaTime: String {
        return "delta_time"
    }
    fileprivate var kChannel: String {
        return "channel"
    }
    fileprivate var kEventNumber: String {
        return "event_number"
    }
    
    class var processor : Processor {
        struct Static {
            static let sharedInstance : Processor = Processor()
        }
        return Static.sharedInstance
    }
    
    func processDataWithCompletion(_ completion: (() -> ())?) {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async { () -> Void in
            self.processData()
            completion?()
        }
    }
    
    func selectData() {
        DataLoader.load { (files: [String]) -> () in
            self.selectedFiles = files
        }
    }
    
    func selectCalibration() {
        Calibration.openCalibration { (calibration: Calibration?) -> () in
            if let calibration = calibration {
                self.calibration = calibration
            }
        }
    }    
    
    // MARK: - Private
    // TODO: implementation
    
    fileprivate func processData() {
        
    }
}
