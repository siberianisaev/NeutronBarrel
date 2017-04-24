//
//  ISAProcessor.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SearchType) {
    SearchTypeFission,
    SearchTypeAlpha,
    SearchTypeRecoil
};

typedef NS_ENUM(NSInteger, TOFUnits) {
    TOFUnitsChannels,
    TOFUnitsNanoseconds
};

@protocol ProcessorDelegate <NSObject>

- (void)incrementProgress:(double)delta;
- (void)startProcessingFile:(NSString *)fileName;

@end

@interface ISAProcessor : NSObject

@property (assign, nonatomic) double fissionAlphaFrontMinEnergy;
@property (assign, nonatomic) double fissionAlphaFrontMaxEnergy;
@property (assign, nonatomic) double recoilFrontMinEnergy;
@property (assign, nonatomic) double recoilFrontMaxEnergy;
@property (assign, nonatomic) double minTOFValue;
@property (assign, nonatomic) double maxTOFValue;
@property (assign, nonatomic) double recoilMinTime;
@property (assign, nonatomic) double recoilMaxTime;
@property (assign, nonatomic) double recoilBackMaxTime;
@property (assign, nonatomic) double fissionAlphaMaxTime;
@property (assign, nonatomic) double maxTOFTime;
@property (assign, nonatomic) double maxGammaTime;
@property (assign, nonatomic) double maxNeutronTime;
@property (assign, nonatomic) int recoilFrontMaxDeltaStrips;
@property (assign, nonatomic) int recoilBackMaxDeltaStrips;
@property (assign, nonatomic) BOOL summarizeFissionsAlphaFront;
@property (assign, nonatomic) BOOL requiredFissionRecoilBack;
@property (assign, nonatomic) BOOL requiredRecoil;
@property (assign, nonatomic) BOOL requiredGamma;
@property (assign, nonatomic) BOOL requiredTOF;
@property (assign, nonatomic) BOOL searchNeutrons;

@property (assign, nonatomic) BOOL searchAlpha2;
@property (assign, nonatomic) double alpha2MinEnergy;
@property (assign, nonatomic) double alpha2MaxEnergy;
@property (assign, nonatomic) double alpha2MinTime;
@property (assign, nonatomic) double alpha2MaxTime;
@property (assign, nonatomic) int alpha2MaxDeltaStrips;

@property (assign, nonatomic) SearchType startParticleType;
@property (assign, nonatomic) TOFUnits unitsTOF;
@property (weak, nonatomic) id <ProcessorDelegate> delegate;

+ (ISAProcessor *)sharedProcessor;

- (void)processDataWithCompletion:(void (^)(void))completion;
- (void)selectDataWithCompletion:(void (^)(BOOL))completion;
- (void)selectCalibrationWithCompletion:(void (^)(BOOL))completion;
- (void)stop;

@end
