//
//  ISAProcessor.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ProcessorDelegate <NSObject>

- (void)incrementProgress:(double)delta;
- (void)startProcessingFile:(NSString *)fileName;

@end

@interface ISAProcessor : NSObject

@property (assign, nonatomic) double fissionFrontMinEnergy;
@property (assign, nonatomic) double fissionFrontMaxEnergy;
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
@property (assign, nonatomic) int recoilFrontMaxDeltaStrips;
@property (assign, nonatomic) int recoilBackMaxDeltaStrips;
@property (assign, nonatomic) BOOL summarizeFissionsFront;
@property (assign, nonatomic) BOOL requiredFissionRecoilBack;
@property (assign, nonatomic) BOOL requiredRecoil;
@property (assign, nonatomic) BOOL requiredGamma;
@property (assign, nonatomic) BOOL requiredTOF;
@property (weak, nonatomic) id <ProcessorDelegate> delegate;

+ (ISAProcessor *)sharedProcessor;

- (void)processDataWithCompletion:(void (^)(void))completion;
- (void)selectData;
- (void)selectCalibration;

@end
