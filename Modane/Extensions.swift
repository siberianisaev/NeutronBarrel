//
//  Extensions.swift
//  Modane
//
//  Created by Andrey Isaev on 29/10/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

extension Event {
    
    func getFloatValue() -> Float {
        let hi = param3
        let lo = param2
        let word = (UInt32(hi) << 16) + UInt32(lo)
        let value = Float(bitPattern: word)
        return value
    }
    
    static let size: Int = MemoryLayout<Event>.size
    static var words: Int {
        return size / MemoryLayout<CUnsignedShort>.size
    }
    
}

extension TimeInterval {
    
    func stringFromSeconds() -> String {
        let seconds = Int(self.truncatingRemainder(dividingBy: 60))
        let minutes = Int((self / 60).truncatingRemainder(dividingBy: 60))
        let hours = Int(self / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
}

extension String {
    
    static func timeStamp() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: Date())
        let sMonth = DateFormatter().monthSymbols[components.month! - 1]
        return String(format: "%d_%@_%dd_%02dh_%02dm_%02ds_%dns", components.year!, sMonth, components.day!, components.hour!, components.minute!, components.second!, components.nanosecond!)
    }
    
}
