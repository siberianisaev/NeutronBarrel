//
//  CSVWriter.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.03.15.
//  Copyright (c) 2018 Flerov Laboratory. All rights reserved.
//

import Foundation

class CSVWriter {
    
    fileprivate var stream: OutputStream!
    fileprivate var encoding: String.Encoding!
    fileprivate var delimiter: Data!
    fileprivate var illegalCharacters: CharacterSet!
    fileprivate var currentLine: UInt = 0
    fileprivate var currentField: UInt = 0
    
    init(path: String?) {
        if let path = path {
            encoding = String.Encoding.utf8
            
            stream = OutputStream(toFileAtPath: path, append: false)
            if stream.streamStatus == .notOpen {
                stream.open()
            }
            
            let delimiterString = ","
            delimiter = delimiterString.data(using: String.Encoding.utf8, allowLossyConversion: true)
            
            let ic = (CharacterSet.newlines as NSCharacterSet).mutableCopy() as! NSMutableCharacterSet
            ic.addCharacters(in: delimiterString)
            ic.addCharacters(in: "\"")
            illegalCharacters = ic.copy() as! CharacterSet
        }
    }
    
    deinit {
        stream.close()
        stream = nil
    }
    
    fileprivate func writeData(_ data: Data) {
        if data.count > 0 {
            stream.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
        }
    }
    
    fileprivate func writeString(_ string: String) {
        let stringData = string.data(using: encoding, allowLossyConversion: true)!
        writeData(stringData)
    }
    
    fileprivate func finishLineIfNecessary() {
        if currentField != 0 {
            finishLine()
        }
    }
    
    func finishLine() {
        writeString("\n")
        currentField = 0
        currentLine += 1
    }
    
    func writeField(_ field: AnyObject?) {
        if currentField > 0 {
            writeData(delimiter)
        }
    
        var string: NSString = ""
        if let field: AnyObject = field {
            string = field.description as NSString
        }
    
        if string.rangeOfCharacter(from: illegalCharacters).location != NSNotFound {
            // replace double quotes with double double quotes
            string = string.replacingOccurrences(of: "\"", with:"\"\"") as NSString
            // surround in double quotes
            string = "\"\(string)\"" as NSString
        }
        writeString(string as String)
        currentField += 1
    }

    func writeLineOfFields(_ fields: [AnyObject]?) {
        finishLineIfNecessary()
    
        if let fields = fields {
            for field in fields {
                writeField(field)
            }
        }
        finishLine()
    }
    
}
