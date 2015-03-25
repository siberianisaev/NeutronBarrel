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
    
    private var calibration = Calibration.defaultCalibration()
    private var selectedFiles = [String]()
    private var neutronsSummPerAct: Int = 0
    private var neutronsMultiplicityTotal = [Int: CUnsignedLongLong]()
    private var recoilsFrontPerAct = [AnyObject]()
    private var tofRealPerAct = [AnyObject]()
    private var fissionsFrontPerAct = [AnyObject]()
    private var fissionsBackPerAct = [AnyObject]()
    private var fissionsWelPerAct = [AnyObject]()
    private var gammaPerAct = [AnyObject]()
    private var tofGenerationsPerAct = [AnyObject]()
    private var fonPerAct: CUnsignedShort?
    private var recoilSpecialPerAct: CUnsignedShort?
    private var firstFissionInfo = [String: AnyObject]() // информация о главном осколке в цикле
    private var firstFissionTime: CUnsignedShort = 0 // время главного осколка в цикле
    private var isNewAct: Bool = false
    private var currentEventNumber: CUnsignedLongLong = 0
    private var mainCycleTimeEvent: Event?
    
    private var kEncoder: String {
        return "encoder"
    }
    private var kStrip0_15: String {
        return "strip_0_15"
    }
    private var kStrip1_48: String {
        return "strip_1_48"
    }
    private var kEnergy: String {
        return "energy"
    }
    private var kDeltaTime: String {
        return "delta_time"
    }
    private var kChannel: String {
        return "channel"
    }
    private var kEventNumber: String {
        return "event_number"
    }
    
    class var processor : Processor {
        struct Static {
            static let sharedInstance : Processor = Processor()
        }
        return Static.sharedInstance
    }
    
    func processDataWithCompletion(completion: (() -> ())?) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
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
    
    private func processData() {
        
    }
}