//
//  ISAElectronicProtocol.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#warning TODO: загружать EventId и Mask из файлов протокола (лежат в папках с данными) EventId's и хранить в словаре-свойстве класса ISAElectronicProtocol.

typedef NS_ENUM(unsigned short, EventId) {
    EventIdFissionFront1 = 1,
    EventIdFissionFront2 = 2,
    EventIdFissionFront3 = 3,
    EventIdFissionBack1 = 4,
    EventIdFissionBack2 = 5,
    EventIdFissionBack3 = 6,
    EventIdFissionWell1 = 7,
    EventIdFissionWell2 = 8,
    EventIdGamma1 = 10,
    EventIdTOF = 12,
    EventIdNeutrons = 18,
    EventIdFON = 24,
    EventIdTrigger = 25
};

typedef NS_ENUM(unsigned short, Mask) {
    MaskFission = 0x0FFF,
    MaskGamma = 0x1FFF,
    MaskTOF = 0x1FFF,
    MaskFON = 0xFFFF,
    MaskTrigger = 0xFFFF
};

extern unsigned short const kFissionMarker;

#import <Foundation/Foundation.h>

@interface ISAElectronicProtocol : NSObject

@end
