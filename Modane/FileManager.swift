//
//  FileManager.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.12.14.
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
        if let path = desktopFilePathWithName("results.txt", folderName: nil) {
            do {
                try string.write(toFile: path, atomically: true, encoding: .utf8)
                NSWorkspace.shared.openFile(path)
            } catch {
                print(error)
            }
        }
    }
    
    fileprivate class func desktopFilePathWithName(_ fileName: String, folderName: String?) -> String? {
        var path = self.desktopFolder()
        if let folderName = folderName {
            path = path?.appendingPathComponent(folderName) as NSString?
            createIfNeedsDirectoryAtPath(path as String?)
        }
        return path?.appendingPathComponent(fileName)
    }
    
    fileprivate class func fileName(prefix: String, folderName: String, timeStamp: String, postfix: String? = nil, fileExtension: String) -> String {
        var components = [prefix, folderName]
        if folderName != timeStamp {
            components.append(timeStamp)
        }
        if let postfix = postfix {
            components.append(postfix)
        }
        return components.joined(separator: "_") + "." + fileExtension
    }
    
}
