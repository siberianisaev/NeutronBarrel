//
//  Event.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 19/02/2018.
//  Copyright © 2018 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    unsigned short eventId;
    unsigned short unusedTime;
    unsigned short param1;
    unsigned short param2;
    unsigned short param3;
} Event;
