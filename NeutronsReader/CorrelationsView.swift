//
//  CorrelationsView.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 06.04.2021.
//  Copyright © 2021 Flerov Laboratory. All rights reserved.
//

import Cocoa

class CorrelationsView: NSView {
    
    @IBOutlet weak var label: NSTextField!
    fileprivate var counts = [Double: CUnsignedLongLong]()
    
    func set(correlations: CUnsignedLongLong, at progress: Double) {
        if correlations > 0 {
            counts[progress/100.0] = correlations
            setNeedsDisplay(visibleRect)
            label.stringValue = "\(counts.values.reduce(0, +).scientific)"
        }
    }
    
    func reset() {
        counts.removeAll()
        label.stringValue = ""
        setNeedsDisplay(visibleRect)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.15).cgColor
        let context = NSGraphicsContext.current?.cgContext
        context?.setLineCap(.round)
        let maxCount = max(counts.values.max() ?? 0, 1)
        let keys = counts.keys.sorted()
        for key in keys {
            context?.beginPath()
            let x = frame.width * CGFloat(key)
            context?.move(to: CGPoint(x: x, y: 0))
            context?.addLine(to: CGPoint(x: x, y: frame.maxY))
            let value = counts[key] ?? 0
            let color = (CGFloat(value) / CGFloat(maxCount))
            NSColor(red: color, green: 0, blue: 0, alpha: 1.0).setStroke()
            context?.setLineWidth(1)
            context?.strokePath()
        }
        
    }
    
}
