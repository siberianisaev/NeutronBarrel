//
//  ISAProcessor.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

extern int kDefaultFissionFrontMinEnergy;

@interface ISAProcessor : NSObject

@property (assign, nonatomic) double fissionFrontMinEnergy;

+ (ISAProcessor *)processor;

- (void)processData;
- (void)selectData;
- (void)selectCalibration;

@end
