//
//  Extensions.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

import Cocoa

extension NSWindow {
    
    func screenshot() -> NSImage? {
        if let windowImage = CGWindowListCreateImage(CGRect.null, .optionIncludingWindow, CGWindowID(windowNumber), .nominalResolution) {
            return NSImage(cgImage: windowImage, size: frame.size)
        } else {
            return nil
        }
    }
    
}

extension NSImage {
    
    func imagePNGRepresentation() -> Data? {
        if let imageTiffData = tiffRepresentation, let imageRep = NSBitmapImageRep(data: imageTiffData) {
            return imageRep.representation(using: NSBitmapImageRep.FileType.png, properties: [NSBitmapImageRep.PropertyKey.interlaced: NSNumber(value: true)])
        }
        return nil
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
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let sMonth = DateFormatter().monthSymbols[components.month! - 1]
        return String(format: "%d_%@_%d_%02d-%02d-%02d", components.year!, sMonth, components.day!, components.hour!, components.minute!, components.second!)
    }
    
}
