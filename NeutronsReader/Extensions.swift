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
            let imageRef: CGImage = windowImage
            let image = NSImage(cgImage: imageRef, size: frame.size)
            return image
        } else {
            return nil
        }
    }
    
}

extension NSImage {
    
    func imagePNGRepresentation() -> Data? {
        if let imageTiffData = self.tiffRepresentation, let imageRep = NSBitmapImageRep(data: imageTiffData) {
            let imageProps: [String: Any] = [NSImageInterlaced: NSNumber(value: true)]
            let imageData = imageRep.representation(using: NSBitmapImageFileType.PNG, properties: imageProps)
            return imageData
        }
        return nil
    }
    
}