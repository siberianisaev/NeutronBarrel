//
//  TimeStamp.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 21.03.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Foundation

class TimeStamp: NSObject {
    
    class func createTimeStamp() -> String? {
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: Date())
        let sMonth = DateFormatter().monthSymbols[components.month! - 1] as NSString
        return String(format: "%d_%@_%d_%02d-%02d-%02d", components.year!, sMonth, components.day!, components.hour!, components.minute!, components.second!)
    }
    
}
