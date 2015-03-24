//
//  CSVWriter.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.03.15.
//  Copyright (c) 2015 Andrey Isaev. All rights reserved.
//

import Foundation

class CSVWriter: NSObject {
    
    private var stream: NSOutputStream!
    private var encoding: NSStringEncoding!
    private var delimiter: NSData!
    private var illegalCharacters: NSCharacterSet!
    private var currentLine: UInt = 0
    private var currentField: UInt = 0
    
    init(path: String?) {
        super.init()
        
        if let path = path {
            encoding = NSUTF8StringEncoding
            
            stream = NSOutputStream(toFileAtPath: path, append: false)
            if stream.streamStatus == .NotOpen {
                stream.open()
            }
            
            let delimiterString = ","
            delimiter = delimiterString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
            
            var ic = NSCharacterSet.newlineCharacterSet().mutableCopy() as NSMutableCharacterSet
            ic.addCharactersInString(delimiterString)
            ic.addCharactersInString("\"")
            illegalCharacters = ic.copy() as NSCharacterSet
        }
    }
    
    deinit {
        stream.close()
        stream = nil
    }
    
    private func writeData(data: NSData) {
        if data.length > 0 {
            stream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
    }
    
    private func writeString(string: String) {
        var stringData = string.dataUsingEncoding(encoding, allowLossyConversion: true)!
        writeData(stringData)
    }
    
    private func finishLineIfNecessary() {
        if currentField != 0 {
            finishLine()
        }
    }
    
    func finishLine() {
        writeString("\n")
        currentField = 0
        currentLine++
    }
    
    func writeField(field: AnyObject?) {
        if currentField > 0 {
            writeData(delimiter)
        }
    
        var string: NSString = ""
        if let field: AnyObject = field {
            string = field.description
        }
    
        if string.rangeOfCharacterFromSet(illegalCharacters).location != NSNotFound {
            // replace double quotes with double double quotes
            string = string.stringByReplacingOccurrencesOfString("\"", withString:"\"\"")
            // surround in double quotes
            string = "\"\(string)\""
        }
        writeString(string)
        currentField++
    }

    func writeLineOfFields(fields: [AnyObject]?) {
        finishLineIfNecessary()
    
        if let fields = fields {
            for field in fields {
                writeField(field)
            }
        }
        finishLine()
    }
    
}
