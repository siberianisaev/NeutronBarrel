//
//  Settings.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 19.03.15.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

enum Setting: String {
    case
    NeutronsDetectorEfficiency = "NeutronsDetectorEfficiency",
    NeutronsDetectorEfficiencyError = "NeutronsDetectorEfficiencyError",
    ExcludeNeutronCounters = "ExcludeNeutronCounters",
    CounterConfiguration = "CounterConfiguration",
    SFSourcePlaced = "SFSourcePlaced",
    SFSource = "SFSource",
    MinFissionEnergy = "MinFissionEnergy",
    MaxFissionEnergy = "MaxFissionEnergy",
    MinFissionBackEnergy = "MinFissionBackEnergy",
    MaxFissionBackEnergy = "MaxFissionBackEnergy",
    MinRecoilFrontEnergy = "MinRecoilFrontEnergy",
    MaxRecoilFrontEnergy = "MaxRecoilFrontEnergy",
    MinRecoilBackEnergy = "MinRecoilBackEnergy",
    MaxRecoilBackEnergy = "MaxRecoilBackEnergy",
    MinFissionWellEnergy = "MinFissionWellEnergy",
    MaxFissionWellEnergy = "MaxFissionWellEnergy",
    MaxFissionWellAngle = "MaxFissionWellAngle",
    MinRecoilTime = "MinRecoilTime",
    MaxRecoilTime = "MaxRecoilTime",
    MaxRecoilBackTime = "MaxRecoilBackTime",
    MaxRecoilBackBackwardTime = "MaxRecoilBackBackwardTime",
    MaxFissionTime = "MaxFissionTime",
    MaxFissionBackBackwardTime = "MaxFissionBackBackwardTime",
    MaxFissionWellBackwardTime = "MaxFissionWellBackwardTime",
    MaxGammaTime = "MaxGammaTime",
    MaxGammaBackwardTime = "MaxGammaBackwardTime",
    MinNeutronTime = "MinNeutronTime",
    MaxNeutronTime = "MaxNeutronTime",
    MaxNeutronBackwardTime = "MaxNeutronBackwardTime",
    MaxRecoilFrontDeltaStrips = "MaxRecoilFrontDeltaStrips",
    MaxRecoilBackDeltaStrips = "MaxRecoilBackDeltaStrips",
    SummarizeFissionsFront = "SummarizeFissionsFront",
    SummarizeFissionsFront2 = "SummarizeFissionsFront2",
    SummarizeFissionsFront3 = "SummarizeFissionsFront3",
    SummarizeFissionsFront4 = "SummarizeFissionsFront4",
    SummarizeFissionsBack = "SummarizeFissionsBack",
    RequiredFissionAlphaBack = "RequiredFissionAlphaBack",
    SearchFirstRecoilOnly = "SearchFirstRecoilOnly",
    RequiredTOF = "RequiredTOF",
    SearchTOF = "SearchTOF",
    MaxTOFTime = "MaxTOFTime",
    RequiredRecoilBack = "RequiredRecoilBack",
    RequiredRecoil = "RequiredRecoil",
    RequiredGamma = "RequiredGamma",
    RequiredGammaOrWell = "RequiredGammaOrWell",
    SimplifyGamma = "SimplifyGamma",
    RequiredWell = "RequiredWell",
    WellRecoilsAllowed = "WellRecoilsAllowed",
    SearchExtraFromLastParticle = "SearchExtraFromLastParticle",
    SearchNeutrons = "SearchNeutrons",
    NeutronsBackground = "NeutronsBackground",
    SimultaneousDecaysFilterForNeutrons = "SimultaneousDecaysFilterForNeutrons",
    CollapseNeutronOverlays = "CollapseNeutronOverlays",
    NeutronsPositions = "NeutronsPositions",
    SearchFissionAlpha1 = "SearchFissionAlpha1",
    SearchFissionAlpha2 = "SearchFissionAlpha2",
    SearchFissionAlpha3 = "SearchFissionAlpha3",
    SearchFissionAlpha4 = "SearchFissionAlpha4",
    TrackBeamEnergy = "TrackBeamEnergy",
    TrackBeamCurrent = "TrackBeamCurrent",
    TrackBeamBackground = "TrackBeamBackground",
    TrackBeamIntegral = "TrackBeamIntegral",
    MinFissionAlpha2Energy = "MinFissionAlpha2Energy",
    MinFissionAlpha3Energy = "MinFissionAlpha3Energy",
    MinFissionAlpha4Energy = "MinFissionAlpha4Energy",
    MaxFissionAlpha2Energy = "MaxFissionAlpha2Energy",
    MaxFissionAlpha3Energy = "MaxFissionAlpha3Energy",
    MaxFissionAlpha4Energy = "MaxFissionAlpha4Energy",
    MinFissionAlpha2BackEnergy = "MinFissionAlpha2BackEnergy",
    MinFissionAlpha3BackEnergy = "MinFissionAlpha3BackEnergy",
    MinFissionAlpha4BackEnergy = "MinFissionAlpha4BackEnergy",
    MaxFissionAlpha2BackEnergy = "MaxFissionAlpha2BackEnergy",
    MaxFissionAlpha3BackEnergy = "MaxFissionAlpha3BackEnergy",
    MaxFissionAlpha4BackEnergy = "MaxFissionAlpha4BackEnergy",
    MinFissionAlpha2Time = "MinFissionAlpha2Time",
    MinFissionAlpha3Time = "MinFissionAlpha3Time",
    MinFissionAlpha4Time = "MinFissionAlpha4Time",
    MaxFissionAlpha2Time = "MaxFissionAlpha2Time",
    MaxFissionAlpha3Time = "MaxFissionAlpha3Time",
    MaxFissionAlpha4Time = "MaxFissionAlpha4Time",
    MaxFissionAlpha2FrontDeltaStrips = "MaxFissionAlpha2FrontDeltaStrips",
    MaxFissionAlpha3FrontDeltaStrips = "MaxFissionAlpha3FrontDeltaStrips",
    MaxFissionAlpha4FrontDeltaStrips = "MaxFissionAlpha4FrontDeltaStrips",
    MaxConcurrentOperations = "MaxConcurrentOperations",
    SearchSpecialEvents = "SearchSpecialEvents",
    SpecialEventIds = "SpecialEventIds",
    GammaEncodersOnly = "GammaEncodersOnly",
    GammaEncoderIds = "GammaEncoderIds",
    SearchFissionBackByFact = "SearchFissionBackByFact",
    SearchFissionBack2ByFact = "SearchFissionBack2ByFact",
    SearchFissionBack3ByFact = "SearchFissionBack3ByFact",
    SearchFissionBack4ByFact = "SearchFissionBack4ByFact",
    SearchRecoilBackByFact = "SearchRecoilBackByFact",
    SearchWell = "SearchWell",
    SearchRecoils = "SearchRecoils",
    ResultsFolderName = "ResultsFolderName",
    InBeamOnly = "InBeamOnly",
    OutBeamOnly = "OutBeamOnly",
    UseOverflow = "UseOverflow",
    UsePileUp = "UsePileUp"
}

class Settings {
    
    fileprivate static let keySettings = "Settings"
    
    class func change(_ dict: [Setting: Any?]) {
        var info = [String: Any]()
        for (setting, object) in dict {
            if let object = object {
                info[setting.rawValue] = object
            }
        }
        let ud = UserDefaults.standard
        ud.set(info, forKey: keySettings)
        ud.synchronize()
    }
    
    class func changeSingle(_ name: Setting, value: Any?) {
        let ud = UserDefaults.standard
        var settings: [String: Any] = (ud.value(forKey: keySettings) as? [String: Any]) ?? [:]
        settings[name.rawValue] = value
        ud.set(settings, forKey: keySettings)
        ud.synchronize()
    }
    
    class func getStringSetting(_ setting: Setting) -> String? {
        return getSetting(setting) as? String
    }
    
    class func getDoubleSetting(_ setting: Setting) -> Double {
        let object = getSetting(setting) as? Double
        return object ?? 0
    }
    
    class func getUInt64Setting(_ setting: Setting, defaultValue: UInt64 = 0) -> UInt64 {
        let object = getSetting(setting) as? UInt64
        return object ?? defaultValue
    }
    
    class func getIntSetting(_ setting: Setting, defaultValue: Int = 0) -> Int {
        let object = getSetting(setting) as? Int
        return object ?? defaultValue
    }
    
    class func getBoolSetting(_ setting: Setting) -> Bool {
        let object = getSetting(setting) as? Bool
        return object ?? false
    }
    
    fileprivate class func currentSettings() -> [String: Any]? {
        return UserDefaults.standard.object(forKey: keySettings) as? [String: Any]
    }
    
    class func readFromFile(_ completion: @escaping ((Bool)->())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                var success: Bool = false
                if let url = panel.urls.first {
                    do {
                        let data = try Data(contentsOf: url)
                        if let dict = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any] {
                            let ud = UserDefaults.standard
                            ud.set(dict, forKey: keySettings)
                            ud.synchronize()
                            success = true
                        }
                    } catch {
                        print(error)
                    }
                }
                completion(success)
            }
        }
    }
    
    class func writeToFile(_ fileURL: URL?) {
        if let dict = currentSettings(), let url = fileURL {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
                try data.write(to: url)
            } catch {
                print(error)
            }
        }
    }
    
    fileprivate class func getSetting(_ setting: Setting) -> Any? {
        let key = setting.rawValue
        if let object = currentSettings()?[key] {
            return object
        }
        
        switch setting {
        case .NeutronsDetectorEfficiency:
            return 43
        case .MaxConcurrentOperations:
            return 8
        case .MinFissionEnergy, .MaxFissionAlpha2Energy, .MaxFissionAlpha2BackEnergy, .MaxFissionAlpha3Energy, .MaxFissionAlpha4Energy, .MaxFissionAlpha3BackEnergy, .MaxFissionAlpha4BackEnergy, .MaxRecoilFrontEnergy, .MaxRecoilBackEnergy:
            return 20
        case .MaxFissionAlpha2Time, .MaxFissionAlpha3Time, .MaxFissionAlpha4Time, .MaxFissionEnergy, .MaxRecoilTime, .MaxFissionWellEnergy:
            return 1000
        case .MaxFissionWellAngle:
            return 10
        case .MinRecoilFrontEnergy, .MinRecoilBackEnergy, .NeutronsDetectorEfficiencyError:
            return 1
        case .MaxFissionBackEnergy:
            return 10000
        case .MaxRecoilBackTime, .MaxFissionTime, .MaxGammaTime, .MinFissionAlpha2Energy, .MinFissionAlpha2BackEnergy, .MinFissionAlpha3Energy, .MinFissionAlpha4Energy, .MinFissionAlpha3BackEnergy, .MinFissionAlpha4BackEnergy, .MaxNeutronBackwardTime, .MaxTOFTime:
            return 5
        case .MaxNeutronTime:
            return 132
        case .MinFissionBackEnergy, .MaxRecoilFrontDeltaStrips, .MaxRecoilBackDeltaStrips, .SearchFissionAlpha1, .SearchFissionAlpha2, .SearchFissionAlpha3, .SearchFissionAlpha4, .MinFissionAlpha2Time, .MaxFissionAlpha2FrontDeltaStrips, .MinFissionAlpha3Time, .MinFissionAlpha4Time, .MaxFissionAlpha3FrontDeltaStrips, .MaxFissionAlpha4FrontDeltaStrips, .MinRecoilTime, .MaxFissionBackBackwardTime, .MaxFissionWellBackwardTime, .MaxRecoilBackBackwardTime, .MinFissionWellEnergy, .MaxGammaBackwardTime, .SFSource, .MinNeutronTime:
            return 0
        case .RequiredFissionAlphaBack, .SearchFirstRecoilOnly, .RequiredRecoilBack, .SearchNeutrons, .TrackBeamEnergy, .TrackBeamCurrent, .TrackBeamBackground, .TrackBeamIntegral, .SearchWell, .SearchRecoils:
            return true
        case .SummarizeFissionsFront, .SummarizeFissionsFront2, .SummarizeFissionsFront3, .SummarizeFissionsFront4, .SummarizeFissionsBack, .RequiredRecoil, .RequiredGamma, .RequiredGammaOrWell, .SimplifyGamma, .RequiredWell, .WellRecoilsAllowed, .SearchSpecialEvents, .GammaEncodersOnly, .SearchFissionBackByFact, .SearchFissionBack2ByFact, .SearchFissionBack3ByFact, .SearchFissionBack4ByFact, .SearchRecoilBackByFact, .SearchExtraFromLastParticle, .SFSourcePlaced, .NeutronsPositions, .NeutronsBackground, .SimultaneousDecaysFilterForNeutrons, .CollapseNeutronOverlays, .InBeamOnly, .OutBeamOnly, .UseOverflow, .UsePileUp, .SearchTOF, .RequiredTOF:
            return false
        case .SpecialEventIds, .GammaEncoderIds:
            return nil
        case .ResultsFolderName, .ExcludeNeutronCounters:
            return ""
        case .CounterConfiguration:
            return """
    {513:104,515:115,516:103,517:102,528:107,529:70,530:43,531:106,532:42,533:69,534:41,535:68,536:40,537:67,538:39,539:66,540:38,541:64,542:105,543:116,544:74,546:19,547:71,550:108,551:17,553:73,556:76,557:3,558:77,560:72,561:44,562:45,563:21,564:46,565:22,566:47,567:23,568:48,569:24,570:49,571:25,572:50,573:26,574:51,575:52,576:78,577:109,578:75,579:80,580:81,581:110,582:83,583:82,584:92,585:85,586:111,587:93,588:84,589:79,590:112,591:90,592:27,593:53,594:28,595:54,596:29,597:55,598:30,599:56,600:59,601:32,602:58,603:31,604:57,605:10,606:9,607:11,608:91,609:97,610:5,611:94,612:12,613:6,614:89,615:13,616:7,617:88,618:14,619:8,620:87,621:113,622:86,623:114,624:35,625:36,626:37,627:63,628:62,629:34,630:33,631:98,632:99,633:65,634:100,635:101,636:60,637:61,638:95,639:96}
    """ // 2026
        }
    }
    
}
