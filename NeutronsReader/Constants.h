//
//  Constants.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 08/05/2017.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(unsigned short, Mask) {
    MaskHeavyOrFission = 0x0FFF,
    MaskGamma = 0x1FFF,
    MaskTOF = 0x1FFF,
    MaskRecoilOrAlpha = 0x1FFF,
    MaskSpecial = 0xFFFF,
    MaskNeutrons = 0x007F
};
