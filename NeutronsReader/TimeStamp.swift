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
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(NSCalendarUnit.YearCalendarUnit|NSCalendarUnit.MonthCalendarUnit|NSCalendarUnit.DayCalendarUnit|NSCalendarUnit.HourCalendarUnit|NSCalendarUnit.MinuteCalendarUnit|NSCalendarUnit.SecondCalendarUnit, fromDate: NSDate())
        var sMonth = NSDateFormatter().monthSymbols[components.month - 1] as! NSString
        return String(format: "%d_%@_%d_%02d-%02d-%02d", components.year, sMonth, components.day, components.hour, components.minute, components.second)
    }
    
}
