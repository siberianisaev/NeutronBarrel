//
//  SideDetector.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 25/04/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

// TODO: старый и новый детекторы
class SideDetector: DoubleSidedDetector {
    
    override class func stripsCount() -> (front: Int, back: Int) {
        return (16, 16)
    }
    
    override class func activeAreaSize() -> CGSize {
        return CGSize(width: 46, height: 60)
    }
    
    static var interCristalPadding: CGFloat {
        return 8.0
    }
    
}
