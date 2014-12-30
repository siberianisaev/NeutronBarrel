//
//  DataLoader.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 30.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

import Foundation
import AppKit

@objc
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
                    if let path = (URL as? NSURL)?.path  {
                        var isDirectory: ObjCBool = false
                        if fm.fileExistsAtPath(path, isDirectory: &isDirectory) && isDirectory {
                            //TODO: использовать файл протокола для уточнения данных
                            let predicate = NSPredicate(format: "!(self ENDSWITH '.PRO') AND !(self ENDSWITH '.DS_Store')")
                            var error: NSError? = nil
                            if let files = (fm.contentsOfDirectoryAtPath(path, error: &error)? as NSArray?)?.filteredArrayUsingPredicate(predicate!) {
                                for fileName in files {
                                    selected.append(path.stringByAppendingPathComponent(fileName as String))
                                }
                            }
                        } else {
                            selected.append(path)
                        }
                    }
                }
                onFinish(selected)
            }
        }
    }
    
}
