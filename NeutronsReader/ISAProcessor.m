//
//  ISAProcessor.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISAProcessor.h"

@interface ISAProcessor ()

@property (strong, nonatomic) Processor *processor;

@end

@implementation ISAProcessor

+ (ISAProcessor *)sharedProcessor
{
    static ISAProcessor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ISAProcessor alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    if (self = [super init]) {
        _calibration = [[Calibration alloc] init];
        _files = [NSArray array];
    }
    return self;
}
    
- (void)stop
{
    _stoped = YES;
}

- (void)processDataWithCompletion:(void (^)(void))completion
{
    _stoped = NO;
    
    __weak ISAProcessor *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ISAProcessor *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf processData];
        }
        if (completion) {
            completion();
        }
    });
}

- (void)processData
{
    if (0 == _files.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Error"];
            [alert setInformativeText:@"Please select some data files to start analysis!"];
            [alert addButtonWithTitle:@"OK"];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert runModal];
        });
        return;
    }
    
    _processor = [Processor new];
    _processor.p = self;
    
    _neutronsMultiplicityTotal = [NSMutableDictionary dictionary];
    _recoilsFrontPerAct = [NSMutableArray array];
    _alpha2FrontPerAct = [NSMutableArray array];
    _tofRealPerAct = [NSMutableArray array];
    _fissionsAlphaFrontPerAct = [NSMutableArray array];
    _fissionsAlphaBackPerAct = [NSMutableArray array];
    _gammaPerAct = [NSMutableArray array];
    _tofGenerationsPerAct = [NSMutableArray array];
    _fissionsAlphaWelPerAct = [NSMutableArray array];
    _totalEventNumber = 0;
    
    _logger = [[Logger alloc] init];
    [self logInput];
    [self logCalibration];
    [self logResultsHeader];
    
    [_delegate incrementProgress:LDBL_EPSILON]; // Show progress indicator
    const double progressForOneFile = 100.0 / _files.count;
    
    for (NSString *path in _files) {
        @autoreleasepool {
            _file = fopen([path UTF8String], "rb");
            _currentFileName = path.lastPathComponent;
            [_delegate startProcessingFile:_currentFileName];
            
            if (_file == NULL) {
                exit(-1);
            } else {
                setvbuf(_file, NULL, _IONBF, 0); // disable buffering
                __weak ISAProcessor *weakSelf = self;
                [_processor forwardSearchWithChecker:^(ISAEvent event, BOOL *stop) {
                    ISAProcessor *strongSelf = weakSelf;
                    if (strongSelf) {
                        if (ferror(strongSelf.file)) {
                            printf("\nERROR while reading file %s\n", [strongSelf.currentFileName UTF8String]);
                            exit(-1);
                        }
                        if (strongSelf.stoped) {
                            *stop = YES;
                        }
                        [strongSelf mainCycleEventCheck:event];
                    }
                }];
            }
            
            fseek(_file, 0L, SEEK_END);
            fpos_t lastNumber;
            fgetpos(_file, &lastNumber);
            _totalEventNumber += (unsigned long long)lastNumber/sizeof(ISAEvent);
            
            fclose(_file);
            
            [_delegate incrementProgress:progressForOneFile];
        }
    }
    
    if (_searchNeutrons) {
        [_logger logMultiplicity:_neutronsMultiplicityTotal];
    }
}

- (void)mainCycleEventCheck:(ISAEvent)event
{
    if (event.eventId == _dataProtocol.CycleTime) {
        _mainCycleTimeEvent = event;
    }
    
    // FFron or AFron
    if ([_processor isFront:event type:_startParticleType]) {
        // Запускаем новый цикл поиска, только если энергия осколка/альфы на лицевой стороне детектора выше минимальной
        double energy = [_processor getEnergy:event type:_startParticleType];
        if (energy < _fissionAlphaFrontMinEnergy || energy > _fissionAlphaFrontMaxEnergy) {
            return;
        }
        [self storeFirstFissionAlphaFront:event];
        
        fpos_t position;
        fgetpos(_file, &position);
        
        // Alpha 2
        if (_searchAlpha2) {
            [_processor findAlpha2];
            fseek(_file, position, SEEK_SET);
            if (0 == _alpha2FrontPerAct.count) {
                [self clearActInfo];
                return;
            }
        }
        
        // Gamma
        [_processor findGamma];
        fseek(_file, position, SEEK_SET);
        if (_requiredGamma && 0 == _gammaPerAct.count) {
            [self clearActInfo];
            return;
        }
        
        // FBack or ABack
        [self findFissionsAlphaBack];
        fseek(_file, position, SEEK_SET);
        if (_requiredFissionRecoilBack && 0 == _fissionsAlphaBackPerAct.count) {
            [self clearActInfo];
            return;
        }
        
        // Recoil (Ищем рекойлы только после поиска всех FBack/ABack!)
        [_processor findRecoil];
        fseek(_file, position, SEEK_SET);
        if (_requiredRecoil && 0 == _recoilsFrontPerAct.count) {
            [self clearActInfo];
            return;
        }
        
        // Neutrons
        if (_searchNeutrons) {
            [_processor findNeutrons];
            fseek(_file, position, SEEK_SET);
        }
        
        // FON & Recoil Special && TOF Generations
        [_processor findFONEvents];
        fseek(_file, position, SEEK_SET);
        
        // FWel or AWel
        [_processor findFissionsAlphaWel];
        fseek(_file, position, SEEK_SET);
        
        /*
         ВАЖНО: тут не делаем репозиционирование в потоке после поиска!
         Этот подцикл поиска всегда должен быть последним!
         */
        // Summ(FFron or AFron)
        if (_summarizeFissionsAlphaFront) {
            [_processor findFissionsAlphaFront];
        }
        
        // Завершили поиск корреляций
        if (_searchNeutrons) {
            [self updateNeutronsMultiplicity];
        }
        [self logActResults];
        [self clearActInfo];
    }
}

/**
 Ищем все FBack/ABack в окне <= _fissionAlphaMaxTime относительно времени FFron.
 */
- (void)findFissionsAlphaBack
{
    NSSet *directions = [NSSet setWithObject:@(SearchDirectionForward)];
    [_processor searchWithDirections:directions startTime:_firstFissionAlphaTime minDeltaTime:0 maxDeltaTime:_fissionAlphaMaxTime useCycleTime:NO updateCycleEvent:NO checker:^(ISAEvent event, unsigned long long time, long long deltaTime, BOOL *stop) {
        if ([_processor isBack:event type:_startParticleType]) {
            double energy = [_processor getEnergy:event type:_startParticleType];
            if (energy >= _fissionAlphaFrontMinEnergy && energy <= _fissionAlphaFrontMaxEnergy) {
                [self storeFissionAlphaBack:event deltaTime:(int)deltaTime];
            }
        }
    }];
    
    if (_fissionsAlphaBackPerAct.count > 1) {
        NSDictionary *dict = [[_fissionsAlphaBackPerAct sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSDictionary *item1 = (NSDictionary *)obj1;
            NSDictionary *item2 = (NSDictionary *)obj2;
            return ([[item1 objectForKey:kEnergy] doubleValue] > [[item2 objectForKey:kEnergy] doubleValue]);
        }] firstObject];
        unsigned short encoder = [[dict objectForKey:kEncoder] unsignedShortValue];
        unsigned short strip0_15 = [[dict objectForKey:kStrip0_15] unsignedShortValue];
        unsigned short strip1_48 = [_processor stripConvertToFormat_1_48:strip0_15 encoder:encoder];
        
        _fissionsAlphaBackPerAct = [[_fissionsAlphaBackPerAct filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            NSDictionary *item = (NSDictionary *)obj;
            if ([item isEqual:dict]) {
                return YES;
            }
            unsigned short e = [[item objectForKey:kEncoder] unsignedShortValue];
            unsigned short s0_15 = [[item objectForKey:kStrip0_15] unsignedShortValue];
            unsigned short s1_48 = [_processor stripConvertToFormat_1_48:s0_15 encoder:e];
            // TODO: new input field for _fissionBackMaxDeltaStrips
            return (abs(strip1_48 - s1_48) <= _recoilBackMaxDeltaStrips);
        }]] mutableCopy];
    }
}

- (void)storeFissionAlphaBack:(ISAEvent)event deltaTime:(long long)deltaTime
{
    unsigned short encoder = [_processor fissionAlphaRecoilEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    double energy = [_processor getEnergy:event type:_startParticleType];
    NSDictionary *info = @{kEncoder:@(encoder),
                           kStrip0_15:@(strip_0_15),
                           kEnergy:@(energy),
                           kEventNumber:@([_processor eventNumber]),
                           kDeltaTime: @(deltaTime)};
    [_fissionsAlphaBackPerAct addObject:info];
}

- (void)storeGamma:(ISAEvent)event deltaTime:(long long)deltaTime
{
    unsigned short channel = event.param3 & MaskGamma;
    double energy = [_calibration calibratedValueForAmplitude:channel eventName:@"Gam1"]; // TODO: Gam2, Gam
    NSDictionary *info = @{kEnergy:@(energy),
                           kDeltaTime: @(deltaTime)};
    [_gammaPerAct addObject:info];
}
    
- (void)storeRecoil:(ISAEvent)event deltaTime:(long long)deltaTime
{
    double energy = [_processor getEnergy:event type:SearchTypeRecoil];
    NSDictionary *info = @{kEnergy:@(energy),
                           kDeltaTime:@(deltaTime),
                           kEventNumber:@([_processor eventNumber])};
    [_recoilsFrontPerAct addObject:info];
}

- (void)storeAlpha2:(ISAEvent)event deltaTime:(long long)deltaTime
{
    double energy = [_processor getEnergy:event type:SearchTypeAlpha];
    NSDictionary *info = @{kEnergy:@(energy),
                           kDeltaTime:@(deltaTime),
                           kEventNumber:@([_processor eventNumber])};
    [_alpha2FrontPerAct addObject:info];
}

- (double)nanosecondsForTOFChannel:(unsigned short)channelTOF eventRecoil:(ISAEvent)eventRecoil
{
    unsigned short eventId = eventRecoil.eventId;
    unsigned short strip_0_15 = eventRecoil.param2 >> 12;  // value from 0 to 15
    unsigned short encoder = [_processor fissionAlphaRecoilEncoderForEventId:eventId];
    NSString *position = nil;
    if ([_dataProtocol AFron:1] == eventId || [_dataProtocol AFron:2] == eventId || [_dataProtocol AFron:3] == eventId) {
        position = @"Fron";
    } else {
        position = @"Back";
    }
    NSString *name = [NSString stringWithFormat:@"T%@%d.%d", position, encoder, strip_0_15+1];
    return [_calibration calibratedValueForAmplitude:channelTOF eventName:name];
}

- (double)valueTOF:(ISAEvent)eventTOF forRecoil:(ISAEvent)eventRecoil
{
    double channel = [_processor channelForTOF:eventTOF];
    if (_unitsTOF == TOFUnitsChannels) {
        return channel;
    } else {
        return [self nanosecondsForTOFChannel:channel eventRecoil:eventRecoil];
    }
}

- (void)storeRealTOFValue:(double)value deltaTime:(long long)deltaTime
{
    NSDictionary *info = @{kValue:@(value),
                           kDeltaTime:@(deltaTime)};
    [_tofRealPerAct addObject:info];
}

- (void)storeFON:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskFON;
    _fonPerAct = @(channel);
}

- (void)storeRecoilSpecial:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskRecoilSpecial;
    _recoilSpecialPerAct = @(channel);
}

/**
 Используется для определения суммарной множественности нейтронов во всех файлах
 */
- (void)updateNeutronsMultiplicity
{
    unsigned long long summ = [[_neutronsMultiplicityTotal objectForKey:@(_neutronsSummPerAct)] unsignedLongLongValue];
    summ += 1; // Одно событие для всех нейтронов в одном акте деления
    [_neutronsMultiplicityTotal setObject:@(summ) forKey:@(_neutronsSummPerAct)];
}

- (void)storeFirstFissionAlphaFront:(ISAEvent)event
{
    [self storeFissionAlphaFront:event isFirst:YES deltaTime:0];
}

- (void)storeNextFissionAlphaFront:(ISAEvent)event deltaTime:(long long)deltaTime
{
    [self storeFissionAlphaFront:event isFirst:NO deltaTime:deltaTime];
}

- (void)storeFissionAlphaFront:(ISAEvent)event isFirst:(BOOL)isFirst deltaTime:(long long)deltaTime
{
    unsigned short channel = (_startParticleType == SearchTypeFission) ? (event.param2 & MaskFission) : (event.param3 & MaskRecoilAlpha);
    unsigned short encoder = [_processor fissionAlphaRecoilEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    double energy = [_processor getEnergy:event type:_startParticleType];
    NSDictionary *info = @{kEncoder:@(encoder),
                           kStrip0_15:@(strip_0_15),
                           kChannel:@(channel),
                           kEnergy:@(energy),
                           kEventNumber:@([_processor eventNumber]),
                           kDeltaTime:@(deltaTime)};
    [_fissionsAlphaFrontPerAct addObject:info];
    
    if (isFirst) {
        unsigned short strip_1_48 = [_processor focalStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
        NSMutableDictionary *extraInfo = [info mutableCopy];
        [extraInfo setObject:@(strip_1_48) forKey:kStrip1_48];
        _firstFissionAlphaInfo = extraInfo;
        _firstFissionAlphaTime = event.param1;
    }
}

- (void)storeFissionAlphaWell:(ISAEvent)event
{
    double energy = [_processor getEnergy:event type:_startParticleType];
    unsigned short encoder = [_processor fissionAlphaRecoilEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    NSDictionary *info = @{kEncoder:@(encoder),
                           kStrip0_15:@(strip_0_15),
                           kEnergy:@(energy)};
    [_fissionsAlphaWelPerAct addObject:info];
}

- (void)storeTOFGenerations:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskTOF;
    [_tofGenerationsPerAct addObject:@(channel)];
}

- (void)clearActInfo
{
    _neutronsSummPerAct = 0;
    [_fissionsAlphaFrontPerAct removeAllObjects];
    [_fissionsAlphaBackPerAct removeAllObjects];
    [_gammaPerAct removeAllObjects];
    [_tofGenerationsPerAct removeAllObjects];
    [_fissionsAlphaWelPerAct removeAllObjects];
    [_recoilsFrontPerAct removeAllObjects];
    [_alpha2FrontPerAct removeAllObjects];
    [_tofRealPerAct removeAllObjects];
    _firstFissionAlphaInfo = nil;
    _fonPerAct = nil;
    _recoilSpecialPerAct = nil;
}

- (NSDictionary *)fissionAlphaBackWithMaxEnergyInAct
{
    NSDictionary *fission = nil;
    double maxE = 0;
    for (int i = 0; i < _fissionsAlphaBackPerAct.count; i++) {
        NSDictionary *info = [_fissionsAlphaBackPerAct objectAtIndex:i];
        double e = [[info objectForKey:kEnergy] doubleValue];
        if (maxE < e) {
            maxE = e;
            fission = info;
        }
    }
    return fission;
}

- (void)logInput
{
    NSImage *image = [[(AppDelegate *)[[NSApplication sharedApplication] delegate] window] screenshot];
    [_logger logInput:image];
}

- (void)logCalibration
{
    [_logger logCalibration:_calibration.stringValue];
}

- (void)logResultsHeader
{
    NSString *startParticle = (_startParticleType == SearchTypeFission) ? @"F" : @"A";
    NSString *header = [NSString stringWithFormat:@"Event(Recoil),E(RFron),dT(RFron-$Fron),TOF,dT(TOF-RFron),Event($),Summ($Fron),$Fron,dT($FronFirst-Next),Strip($Fron),$Back,dT($Fron-$Back),Strip($Back),$Wel,$WelPos,Neutrons,Gamma,dT($Fron-Gamma),FON,Recoil(Special)"];
    if (_searchAlpha2) {
        header = [header stringByAppendingString:@",Event(Alpha2),E(Alpha2),dT(Alpha1-Alpha2)"];
    }
    header = [header stringByReplacingOccurrencesOfString:@"$" withString:startParticle];
    NSArray *components = [header componentsSeparatedByString:@","];
    [_logger writeLineOfFields:components];
    [_logger finishLine]; // +1 line padding
}

- (void)logActResults
{
    int columnsCount = 19;
    if (_searchAlpha2) {
        columnsCount += 3;
    }
    int rowsMax = MAX(MAX(MAX(MAX(MAX(1, (int)_gammaPerAct.count), (int)_fissionsAlphaWelPerAct.count), (int)_recoilsFrontPerAct.count), (int)_fissionsAlphaBackPerAct.count), (int)_fissionsAlphaFrontPerAct.count);
    for (int row = 0; row < rowsMax; row++) {
        for (int column = 0; column <= columnsCount; column++) {
            NSString *field = @"";
            switch (column) {
                case 0:
                {
                    if (row < (int)_recoilsFrontPerAct.count) {
                        NSNumber *eventNumberObject = [[_recoilsFrontPerAct objectAtIndex:row] objectForKey:kEventNumber];
                        if (eventNumberObject) {
                            field = [_processor currentFileEventNumber:[eventNumberObject unsignedLongLongValue]];
                        }
                    }
                    break;
                }
                case 1:
                {
                    if (row < (int)_recoilsFrontPerAct.count) {
                        NSNumber *recoilEnergy = [[_recoilsFrontPerAct objectAtIndex:row] valueForKey:kEnergy];
                        if (recoilEnergy) {
                            field = [NSString stringWithFormat:@"%.7f", [recoilEnergy doubleValue]];
                        }
                    }
                    break;
                }
                case 2:
                {
                    if (row < (int)_recoilsFrontPerAct.count) {
                        NSNumber *deltaTimeRecoilFission = [[_recoilsFrontPerAct objectAtIndex:row] valueForKey:kDeltaTime];
                        if (deltaTimeRecoilFission) {
                            field = [NSString stringWithFormat:@"%lld", (long long)[deltaTimeRecoilFission longLongValue]];
                        }
                    }
                    break;
                }
                case 3:
                {
                    if (row < (int)_tofRealPerAct.count) {
                        NSNumber *tof = [[_tofRealPerAct objectAtIndex:row] valueForKey:kValue];
                        if (tof) {
                            field = [NSString stringWithFormat:@"%hu", [tof unsignedShortValue]];
                        }
                    }
                    break;
                }
                case 4:
                {
                    if (row < (int)_tofRealPerAct.count) {
                        NSNumber *deltaTimeTOFRecoil = [[_tofRealPerAct objectAtIndex:row] valueForKey:kDeltaTime];
                        if (deltaTimeTOFRecoil) {
                            field = [NSString stringWithFormat:@"%lld", (long long)[deltaTimeTOFRecoil longLongValue]];
                        }
                    }
                    break;
                }
                case 5:
                {
                    if (row < (int)_fissionsAlphaFrontPerAct.count) {
                        NSDictionary *info = [_fissionsAlphaFrontPerAct objectAtIndex:row];
                        unsigned long long eventNumber = [[info objectForKey:kEventNumber] unsignedLongLongValue];
                        field = [_processor currentFileEventNumber:eventNumber];
                    }
                    break;
                }
                case 6:
                {
                    if (row == 0) {
                        double summ = 0;
                        for (NSDictionary *info in _fissionsAlphaFrontPerAct) {
                            double energy = [[info objectForKey:kEnergy] doubleValue];
                            summ += energy;
                        }
                        field = [NSString stringWithFormat:@"%.7f", summ];
                    }
                    break;
                }
                case 7:
                {
                    if (row < (int)_fissionsAlphaFrontPerAct.count) {
                        NSDictionary *info = [_fissionsAlphaFrontPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"%.7f", [[info objectForKey:kEnergy] doubleValue]];
                    }
                    break;
                }
                case 8:
                {
                    if (row < (int)_fissionsAlphaFrontPerAct.count) {
                        NSDictionary *info = [_fissionsAlphaFrontPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"%lld", [[info objectForKey:kDeltaTime] longLongValue]];
                    }
                    break;
                }
                case 9:
                {
                    if (row < (int)_fissionsAlphaFrontPerAct.count) {
                        NSDictionary *info = [_fissionsAlphaFrontPerAct objectAtIndex:row];
                        int strip_0_15 = [[info objectForKey:kStrip0_15] intValue];
                        int encoder = [[info objectForKey:kEncoder] intValue];
                        unsigned short strip = [_processor stripConvertToFormat_1_48:strip_0_15 encoder:encoder];
                        field = [NSString stringWithFormat:@"%d", strip];
                    }
                    break;
                }
                case 10:
                {
                    if (row < (int)_fissionsAlphaBackPerAct.count) {
                        NSDictionary *fissionInfo = [_fissionsAlphaBackPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"%.7f", [[fissionInfo objectForKey:kEnergy] doubleValue]];
                    }
                    break;
                }
                case 11:
                {
                    if (row < (int)_fissionsAlphaBackPerAct.count) {
                        NSDictionary *fissionInfo = [_fissionsAlphaBackPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"%d", [[fissionInfo objectForKey:kDeltaTime] intValue]];
                    }
                    break;
                }
                case 12:
                {
                    if (row < (int)_fissionsAlphaBackPerAct.count) {
                        NSDictionary *info = [_fissionsAlphaBackPerAct objectAtIndex:row];
                        int strip_0_15 = [[info objectForKey:kStrip0_15] intValue];
                        int encoder = [[info objectForKey:kEncoder] intValue];
                        unsigned short strip = [_processor stripConvertToFormat_1_48:strip_0_15 encoder:encoder];
                        field = [NSString stringWithFormat:@"%d", strip];
                    }
                    break;
                }
                case 13:
                {
                    if (row < (int)_fissionsAlphaWelPerAct.count) {
                        NSDictionary *fissionInfo = [_fissionsAlphaWelPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"%.7f", [[fissionInfo objectForKey:kEnergy] doubleValue]];
                    }
                    break;
                }
                case 14:
                {
                    if (row < (int)_fissionsAlphaWelPerAct.count) {
                        NSDictionary *fissionInfo = [_fissionsAlphaWelPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"FWel%d.%d", [[fissionInfo objectForKey:kEncoder] intValue], [[fissionInfo objectForKey:kStrip0_15] intValue]+1];
                    }
                    break;
                }
                case 15:
                {
                    if (row == 0 && _searchNeutrons) {
                        field = [NSString stringWithFormat:@"%llu", _neutronsSummPerAct];
                    }
                    break;
                }
                case 16:
                {
                    if (row < (int)_gammaPerAct.count) {
                        NSDictionary *info = [_gammaPerAct objectAtIndex:row];
                        field = [NSString stringWithFormat:@"%.7f", [[info objectForKey:kEnergy] doubleValue]];
                    }
                    break;
                }
                case 17:
                    if (row < (int)_gammaPerAct.count) {
                        NSDictionary *info = [_gammaPerAct objectAtIndex:row];
                        NSNumber *deltaTimeFissionGamma = [info objectForKey:kDeltaTime];
                        if (deltaTimeFissionGamma) {
                            field = [NSString stringWithFormat:@"%d", [deltaTimeFissionGamma intValue]];
                        }
                    }
                    break;
                case 18:
                {
                    if (row == 0 && _fonPerAct) {
                        field = [NSString stringWithFormat:@"%hu", [_fonPerAct unsignedShortValue]];
                    }
                    break;
                }
                case 19:
                {
                    if (row == 0 && _recoilSpecialPerAct) {
                        field = [NSString stringWithFormat:@"%hu", [_recoilSpecialPerAct unsignedShortValue]];
                    }
                    break;
                }
                case 20:
                {
                    if (row < (int)_alpha2FrontPerAct.count) {
                        NSNumber *event = [[_alpha2FrontPerAct objectAtIndex:row] objectForKey:kEventNumber];
                        if (event) {
                            field = [_processor currentFileEventNumber:[event unsignedLongLongValue]];
                        }
                    }
                    break;
                }
                case 21:
                {
                    if (row < (int)_alpha2FrontPerAct.count) {
                        NSNumber *energy = [[_alpha2FrontPerAct objectAtIndex:row] valueForKey:kEnergy];
                        if (energy) {
                            field = [NSString stringWithFormat:@"%.7f", [energy doubleValue]];
                        }
                    }
                    break;
                }
                case 22:
                {
                    if (row < (int)_alpha2FrontPerAct.count) {
                        NSNumber *deltaTime = [[_alpha2FrontPerAct objectAtIndex:row] valueForKey:kDeltaTime];
                        if (deltaTime) {
                            field = [NSString stringWithFormat:@"%lld", (long long)[deltaTime longLongValue]];
                        }
                    }
                    break;
                }
                default:
                    break;
            }
            [_logger writeField:field];
        }
        [_logger finishLine];
    }
}

- (void)selectDataWithCompletion:(void (^)(BOOL))completion
{
    [DataLoader load:^(NSArray *files, DataProtocol *protocol){
        _files = files;
        _dataProtocol = protocol;
        completion(files.count > 0);
    }];
}

- (void)selectCalibrationWithCompletion:(void (^)(BOOL))completion
{
    [Calibration openCalibration:^(Calibration *calibration){
        _calibration = calibration;
        completion(true);
    }];
}

@end
