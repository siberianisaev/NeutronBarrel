//
//  ISAProcessor.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISAProcessor : NSObject

@property (assign, nonatomic) double fissionFrontMinEnergy;
@property (assign, nonatomic) double recoilFrontMinEnergy;
@property (assign, nonatomic) double recoilFrontMaxEnergy;
@property (assign, nonatomic) double minTOFChannel;
@property (assign, nonatomic) double recoilMinTime;
@property (assign, nonatomic) double recoilMaxTime;
@property (assign, nonatomic) double recoilBackMaxTime;
@property (assign, nonatomic) double fissionMaxTime;
@property (assign, nonatomic) double maxTOFTime;
@property (assign, nonatomic) double maxGammaTime;
@property (assign, nonatomic) double maxNeutronTime;
@property (assign, nonatomic) int maxDeltaStrips;
@property (assign, nonatomic) BOOL summarizeFissionsFront;
@property (assign, nonatomic) BOOL requiredFissionBack;
@property (assign, nonatomic) BOOL requiredRecoil;
@property (assign, nonatomic) BOOL requiredGamma;
@property (assign, nonatomic) BOOL requiredTOF;

+ (ISAProcessor *)sharedProcessor;

- (void)processDataWithCompletion:(void (^)(void))completion;
- (void)selectData;
- (void)selectCalibration;

@end
