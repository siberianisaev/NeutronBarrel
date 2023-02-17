//
//  Event.h
//  NeutronBarrel
//
//  Created by Andrey Isaev on 19/02/2018.
//  Copyright © 2018 Flerov Laboratory. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
//    unsigned short eventId;
//    unsigned short param1;
//    unsigned short param2;
//    unsigned short param3;
    
//    channel # uint16
//    energy # uint16
//    overflow # uint8
//    pileup # uint8
//    inbeam # uint8
//    tof # uint8
//    time # uint64
    
    
    UInt16 channel;
    UInt16 energy;
    UInt8 overflow;
    UInt8 pile_up;
    UInt8 in_beam;
    UInt8 tof;
    UInt64 time;
//
//    @staticmethod
//    def from_bytes(bytes):
//
//        def int_from(slice):
//            return int.from_bytes(slice, byteorder='big', signed=False)
//
//        channel = int_from(bytes[0:2])
//        energy = int_from(bytes[2:4])
//        overflow = int_from(bytes[4:5])
//        pile_up = int_from(bytes[5:6])
//        tof = int_from(bytes[6:7])
//        time = int_from(bytes[8:16])
} Event;
