//
//  FileManager.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation

@objc
class FileManager: NSObject {
    
    private class func desktopFolder() -> String? {
        return NSSearchPathForDirectoriesInDomains(.DesktopDirectory, .UserDomainMask, true)[0] as? String
    }
    
    private class func desktopFilePathWithName(fileName: String) -> String? {
        return self.desktopFolder()?.stringByAppendingPathComponent(fileName)
    }
    
    class func resultsFilePath() -> String? {
        return self.desktopFilePathWithName("results.txt")
    }
    
    class func logsFilePath() -> String? {
        return self.desktopFilePathWithName("logs.txt")
    }
    
    class func multiplicityFilePath() -> String? {
        return self.desktopFilePathWithName("multiplicity.txt")
    }
    
    class func calibrationFilePath() -> String? {
        return self.desktopFilePathWithName("calibration.txt")
    }
    
}
