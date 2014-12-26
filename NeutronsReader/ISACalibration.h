//
//  ISACalibration.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 26.11.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISACalibration : NSObject

+ (instancetype)openCalibration;
+ (instancetype)defaultCalibration;

- (double)energyForAmplitude:(unsigned short)channel ofEvent:(NSString *)name;

@end
