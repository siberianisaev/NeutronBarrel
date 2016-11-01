//
//  DataLoader.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 30.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

class DataLoader: NSObject {
    
    class func load(onFinish: (([String]) -> ())) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.beginWithCompletionHandler { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                var selected = [String]()
                let fm = NSFileManager.defaultManager()
                for URL in panel.URLs {
                    if let path = URL.path  {
                        var isDirectory: ObjCBool = false
                        if fm.fileExistsAtPath(path, isDirectory: &isDirectory) && isDirectory {
                            selected += self.recursiveGetFilesFromDirectory(path)
                        } else {
                            selected.append(path)
                        }
                    }
                }
                
                //TODO: использовать файл протокола для уточнения данных
                selected = selected.filter() { false == $0.hasSuffix(".PRO") && false == $0.hasSuffix(".DS_Store") }
                onFinish(selected)
            }
        }
    }
    
    /**
    Метод рекурсивно обходит папки вложенные в directoryPath и возвращает все файлы в ней содержащиеся.
    */
    class func recursiveGetFilesFromDirectory(directoryPath: String) -> [String] {
        var results = [String]()
        
        let fm = NSFileManager.defaultManager()
        do {
            let fileNames = try fm.contentsOfDirectoryAtPath(directoryPath)
            for fileName in fileNames {
                let path = (directoryPath as NSString).stringByAppendingPathComponent(fileName)
                
                var isDirectory: ObjCBool = false
                if fm.fileExistsAtPath(path, isDirectory: &isDirectory) {
                    if isDirectory {
                        results += recursiveGetFilesFromDirectory(path)
                    } else {
                        results.append(path)
                    }
                }
            }
        } catch {
            print(error)
        }
        
        return results
    }
    
}
