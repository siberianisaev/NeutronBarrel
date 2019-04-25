//
//  DoubleSidedDetector.swift
//  NeutronsReader
//
//  Created by Andrey Isaev on 25/04/2019.
//  Copyright © 2019 Flerov Laboratory. All rights reserved.
//

import Foundation

class DoubleSidedDetector {
    
    class func stripsCount() -> (front: Int, back: Int) {
        return (10, 10)
    }
    
    class func activeAreaSize() -> CGSize {
        return CGSize(width: 100, height: 100)
    }
    
    class func stripsWidth() -> (front: CGFloat, back: CGFloat) {
        let size = activeAreaSize()
        let count = stripsCount()
        return (size.width / CGFloat(count.front), size.height / CGFloat(count.back))
    }
    
}
