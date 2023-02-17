//
//  Extensions.swift
//  NeutronBarrel
//
//  Created by Andrey Isaev on 24/04/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

import Cocoa

extension Event {
    
    func getFloatValue() -> Float {
        return Float(time)
//        let hi = param3
//        let lo = param2
//        let word = (UInt32(hi) << 16) + UInt32(lo)
//        let value = Float(bitPattern: word)
//        return value
    }
    
    static let size: Int = MemoryLayout<Event>.size
    static var words: Int {
        return size / MemoryLayout<CUnsignedShort>.size
    }
    
}

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

extension Numeric {
    
    var scientific: String {
        return Formatter.scientific.string(for: self) ?? ""
    }
    
}

extension Formatter {
    
    static let scientific: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .scientific
        f.positiveFormat = "0.###E+0"
        f.exponentSymbol = "e"
        return f
    }()
    
}

extension NSView {
    
    fileprivate func defaultFormColor() -> NSColor {
        return NSColor.lightGray.withAlphaComponent(0.15)
    }
    
    func setupForm(_ color: NSColor? = nil) {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = (color ?? defaultFormColor()).cgColor
    }
}

extension Int {
    
    func factorial() -> Double {
        if self <= 1 {
            return 1
        }
      return (1...self).map(Double.init).reduce(1.0, *)
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

extension timespec {
    
    func toTimeInterval() -> TimeInterval {
        return TimeInterval(tv_sec) + TimeInterval(tv_nsec) * 1e-9
    }
    
}

extension String {
    
    static func timeStamp() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: Date())
        let sMonth = DateFormatter().monthSymbols[components.month! - 1]
        return String(format: "%d_%@_%dd_%02dh_%02dm_%02ds_%dns", components.year!, sMonth, components.day!, components.hour!, components.minute!, components.second!, components.nanosecond!)
    }
    
    func fileNameAndExtension() -> (String?, String?) {
        let components = (self as NSString).components(separatedBy: ".")
        return (components.first, components.last)
    }
    
}

protocol CaseCountable {
    
    static func countCases() -> Int
    static var count : Int { get }
    
}

extension CaseCountable where Self : RawRepresentable, Self.RawValue == Int {
    
    static func countCases() -> Int {
        var count = 0
        while let _ = Self(rawValue: count) { count += 1 }
        return count
    }
    
}

extension Sequence where Element: AdditiveArithmetic {
    func sum() -> Element { reduce(.zero, +) }
}

extension Collection where Element: BinaryFloatingPoint {
    func average() -> Element { isEmpty ? .zero : Element(sum()) / Element(count) }
}

extension Array where Element: Comparable {
    
    func isAscending() -> Bool {
        return zip(self, dropFirst()).allSatisfy(<=)
    }
    
}
