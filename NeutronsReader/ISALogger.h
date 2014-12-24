//
//  ISALogger.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISALogger : NSObject

+ (void)logMultiplicity:(NSDictionary *)info;
+ (void)logCalibration:(NSString *)string;

@end
