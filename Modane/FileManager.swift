//
//  FileManager.swift
//  Modane
//
//  Created by Andrey Isaev on 29/10/2018.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation
import AppKit

class FileManager {
    
    fileprivate class func desktopFolder() -> NSString? {
        return NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first as NSString?
    }
    
    fileprivate class func createIfNeedsDirectoryAtPath(_ path: String?) {
        if let path = path {
            let fm = Foundation.FileManager.default
            if false == fm.fileExists(atPath: path) {
                do {
                    try fm.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    class func writeResults(_ string: String) {
        if let path = desktopFilePathWithName("results.txt") {
            do {
                try string.write(toFile: path, atomically: true, encoding: .utf8)
                NSWorkspace.shared.openFile(path)
            } catch {
                print(error)
            }
        }
    }
    
    fileprivate class func desktopFilePathWithName(_ fileName: String) -> String? {
        let path = self.desktopFolder()
        createIfNeedsDirectoryAtPath(path as String?)
        return path?.appendingPathComponent(fileName)
    }
    
    fileprivate class func fileName(prefix: String, postfix: String? = nil, fileExtension: String) -> String {
        var components = [prefix]
        if let postfix = postfix {
            components.append(postfix)
        }
        return components.joined(separator: "_") + "." + fileExtension
    }
    
}
