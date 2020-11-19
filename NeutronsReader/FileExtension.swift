//
//  FileExtension.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 19.11.2020.
//  Copyright © 2020 Flerov Laboratory. All rights reserved.
//

import Foundation

enum FileExtension: String {
    
    case ini = "ini"
    case cfg = "cfg"
    
    init?(url: URL, length: Int) {
        self.init(rawValue: String(url.path.lowercased().suffix(length)))
    }
    
}
