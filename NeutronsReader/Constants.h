//
//  Constants.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 08/05/2017.
//  Copyright © 2017 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    unsigned short eventId;
    unsigned short param1;
    unsigned short param2;
    unsigned short param3;
} Event;

typedef NS_ENUM(unsigned short, Mask) {
    MaskFission = 0x0FFF,
    MaskGamma = 0x1FFF,
    MaskTOF = 0x1FFF,
    MaskRecoilAlpha = 0x1FFF, // Alpha or Recoil
    MaskSpecial = 0xFFFF
};
