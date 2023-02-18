//
//  Event.h
//  NeutronBarrel
//
//  Created by Andrey Isaev on 19/02/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    
    UInt16 eventId; // TODO: rename to channel
    UInt16 energy;
    UInt8 overflow;
    UInt8 pileUp;
    UInt8 inBeam;
    UInt8 tof;
    UInt64 time;

} Event;
