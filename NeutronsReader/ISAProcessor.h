//
//  ISAProcessor.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    unsigned short eventId;
    unsigned short param1;
    unsigned short param2;
    unsigned short param3;
} ISAEvent;

typedef NS_ENUM(unsigned short, Mask) {
    MaskFission = 0x0FFF,
    MaskGamma = 0x1FFF,
    MaskTOF = 0x1FFF,
    MaskFON = 0xFFFF,
    MaskRecoilAlpha = 0x1FFF, // Alpha or Recoil
    MaskRecoilSpecial = 0xFFFF
};

typedef NS_ENUM(NSInteger, SearchDirection) {
    SearchDirectionForward,
    SearchDirectionBackward
};

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

@class DataProtocol;

@interface ISAProcessor : NSObject

// public during migration to Swift phase
@property (assign, nonatomic) FILE *file;
@property (strong, nonatomic) DataProtocol *dataProtocol;
@property (assign, nonatomic) ISAEvent mainCycleTimeEvent;
@property (assign, nonatomic) unsigned long long totalEventNumber;
@property (assign, nonatomic) unsigned long long firstFissionAlphaTime; // время главного осколка/альфы в цикле
@property (assign, nonatomic) unsigned long long neutronsSummPerAct;

@property (assign, nonatomic) double fissionAlphaFrontMinEnergy;
@property (assign, nonatomic) double fissionAlphaFrontMaxEnergy;
@property (assign, nonatomic) double recoilFrontMinEnergy;
@property (assign, nonatomic) double recoilFrontMaxEnergy;
@property (assign, nonatomic) double minTOFValue;
@property (assign, nonatomic) double maxTOFValue;
@property (assign, nonatomic) double recoilMinTime;
@property (assign, nonatomic) double recoilMaxTime;
@property (assign, nonatomic) double recoilBackMaxTime;
@property (assign, nonatomic) unsigned long long fissionAlphaMaxTime;
@property (assign, nonatomic) double maxTOFTime;
@property (assign, nonatomic) double maxGammaTime;
@property (assign, nonatomic) unsigned long long maxNeutronTime;
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

// public during migration to Swift phase
- (void)storeFissionAlphaWell:(ISAEvent)event;

@end
