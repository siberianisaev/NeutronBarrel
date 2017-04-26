//
//  ISAProcessor.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISAProcessor.h"

/**
 Маркер отличающий осколок/альфу (0) от рекойла (4), записывается в первые 3 бита param3.
 */
static unsigned short kFissionOrAlphaMarker = 0b000;
static unsigned short kRecoilMarker = 0b100;

static NSString * const kEncoder = @"encoder";
static NSString * const kStrip0_15 = @"strip_0_15";
static NSString * const kStrip1_48 = @"strip_1_48";
static NSString * const kEnergy = @"energy";
static NSString * const kValue = @"value";
static NSString * const kDeltaTime = @"delta_time";
static NSString * const kChannel = @"channel";
static NSString * const kEventNumber = @"event_number";

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

@interface ISAProcessor ()

@property (strong, nonatomic) Logger *logger;
@property (strong, nonatomic) Calibration *calibration;
@property (strong, nonatomic) Protocol *dataProtocol;
@property (strong, nonatomic) NSArray *files;
@property (strong, nonatomic) NSString *currentFileName;
@property (strong, nonatomic) NSMutableDictionary *neutronsMultiplicityTotal;
@property (strong, nonatomic) NSMutableArray *recoilsFrontPerAct;
@property (strong, nonatomic) NSMutableArray *alpha2FrontPerAct;
@property (strong, nonatomic) NSMutableArray *tofRealPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsAlphaFrontPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsAlphaBackPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsAlphaWelPerAct;
@property (strong, nonatomic) NSMutableArray *gammaPerAct;
@property (strong, nonatomic) NSMutableArray *tofGenerationsPerAct;
@property (strong, nonatomic) NSNumber *fonPerAct;
@property (strong, nonatomic) NSNumber *recoilSpecialPerAct;
@property (strong, nonatomic) NSDictionary *firstFissionAlphaInfo; // информация о главном осколке/альфе в цикле
@property (assign, nonatomic) unsigned short firstFissionAlphaTime; // время главного осколка/альфы в цикле
@property (assign, nonatomic) unsigned long long neutronsSummPerAct;
@property (assign, nonatomic) FILE *file;
@property (assign, nonatomic) unsigned long long totalEventNumber;
@property (assign, nonatomic) ISAEvent mainCycleTimeEvent;
@property (assign, nonatomic) BOOL stoped;

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
        [weakSelf processData];
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
                while (!feof(_file)) {
                    ISAEvent event;
                    fread(&event, sizeof(event), 1, _file);
                    if (ferror(_file)) {
                        printf("\nERROR while reading file %s\n", [_currentFileName UTF8String]);
                        exit(-1);
                    }
                    
                    if (_stoped) {
                        return;
                    }
                    
                    if (event.eventId == _dataProtocol.CycleTime) {
                        _mainCycleTimeEvent = event;
                    }
                    
                    // FFron or AFron
                    if ([self isFront:event type:_startParticleType]) {
                        // Запускаем новый цикл поиска, только если энергия осколка/альфы на лицевой стороне детектора выше минимальной
                        double energy = [self getEnergy:event type:_startParticleType];
                        if (energy < _fissionAlphaFrontMinEnergy || energy > _fissionAlphaFrontMaxEnergy) {
                            continue;
                        }
                        [self storeFirstFissionAlphaFront:event];
                        
                        fpos_t position;
                        fgetpos(_file, &position);
                        
                        // Alpha 2
                        if (_searchAlpha2) {
                            [self findAlpha2];
                            fseek(_file, position, SEEK_SET);
                            if (0 == _alpha2FrontPerAct.count) {
                                [self clearActInfo];
                                continue;
                            }
                        }
                        
                        // Gamma
                        [self findGamma];
                        fseek(_file, position, SEEK_SET);
                        if (_requiredGamma && 0 == _gammaPerAct.count) {
                            [self clearActInfo];
                            continue;
                        }
                        
                        // FBack or ABack
                        [self findFissionsAlphaBack];
                        fseek(_file, position, SEEK_SET);
                        if (_requiredFissionRecoilBack && 0 == _fissionsAlphaBackPerAct.count) {
                            [self clearActInfo];
                            continue;
                        }
                        
                        // Recoil (Ищем рекойлы только после поиска всех FBack/ABack!)
                        [self findRecoil];
                        fseek(_file, position, SEEK_SET);
                        if (_requiredRecoil && 0 == _recoilsFrontPerAct.count) {
                            [self clearActInfo];
                            continue;
                        }
                        
                        // Neutrons
                        if (_searchNeutrons) {
                            [self findNeutrons];
                            fseek(_file, position, SEEK_SET);
                        }
                        
                        // FON & Recoil Special && TOF Generations
                        [self findFONEvents];
                        fseek(_file, position, SEEK_SET);
                        
                        // FWel or AWel
                        [self findFissionsAlphaWel];
                        fseek(_file, position, SEEK_SET);
                        
                        /*
                         ВАЖНО: тут не делаем репозиционирование в потоке после поиска!
                         Этот подцикл поиска всегда должен быть последним!
                         */
                        // Summ(FFron or AFron)
                        if (_summarizeFissionsAlphaFront) {
                            [self findFissionsAlphaFront];
                        }
                        
                        // Завершили поиск корреляций
                        if (_searchNeutrons) {
                            [self updateNeutronsMultiplicity];
                        }
                        [self logActResults];
                        [self clearActInfo];
                    }
                }
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

/**
 Ищем все Neutrons в окне <= _maxNeutronTime относительно времени FFron.
 */
- (void)findNeutrons
{
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _maxNeutronTime) {
                if (_dataProtocol.Neutrons == event.eventId) {
                    _neutronsSummPerAct += 1;
                }
            } else {
                return;
            }
        }
    }
}

/**
 Ищем все FBack/ABack в окне <= _fissionAlphaMaxTime относительно времени FFron.
 */
- (void)findFissionsAlphaBack
{
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _fissionAlphaMaxTime) {
                if ([self isBack:event type:_startParticleType]) {
                    double energy = [self getEnergy:event type:_startParticleType];
                    if (energy >= _fissionAlphaFrontMinEnergy && energy <= _fissionAlphaFrontMaxEnergy) {
                        [self storeFissionAlphaBack:event deltaTime:deltaTime];
                    }
                }
            } else {
                break;
            }
        }
    }
    
    if (_fissionsAlphaBackPerAct.count > 1) {
        NSDictionary *dict = [[_fissionsAlphaBackPerAct sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSDictionary *item1 = (NSDictionary *)obj1;
            NSDictionary *item2 = (NSDictionary *)obj2;
            return ([[item1 objectForKey:kEnergy] doubleValue] > [[item2 objectForKey:kEnergy] doubleValue]);
        }] firstObject];
        unsigned short encoder = [[dict objectForKey:kEncoder] unsignedShortValue];
        unsigned short strip0_15 = [[dict objectForKey:kStrip0_15] unsignedShortValue];
        unsigned short strip1_48 = [self stripConvertToFormat_1_48:strip0_15 encoder:encoder];
        
        _fissionsAlphaBackPerAct = [[_fissionsAlphaBackPerAct filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            NSDictionary *item = (NSDictionary *)obj;
            if ([item isEqual:dict]) {
                return YES;
            }
            unsigned short e = [[item objectForKey:kEncoder] unsignedShortValue];
            unsigned short s0_15 = [[item objectForKey:kStrip0_15] unsignedShortValue];
            unsigned short s1_48 = [self stripConvertToFormat_1_48:s0_15 encoder:e];
            // TODO: new input field for _fissionBackMaxDeltaStrips
            return (abs(strip1_48 - s1_48) <= _recoilBackMaxDeltaStrips);
        }]] mutableCopy];
    }
}

/**
 Ищем все FFron/AFRon в окне <= _fissionAlphaMaxTime относительно времени T(Fission/Alpha First).
 
 Важно: _mainCycleTimeEvent обновляется при поиске в прямом направлении,
 так как эта часть относится к основному циклу и после поиска не производится репозиционирование потока!
 */
- (void)findFissionsAlphaFront
{
    fpos_t initial;
    fgetpos(_file, &initial);
    
    // 1. Ищем в направлении до -_fissionMaxTime mks от T(Fission First)
    fpos_t current = initial;
    
    if (current > -1) {
        // Skip Fission/Alpha First event!
        current -= sizeof(ISAEvent);
        fseek(_file, current, SEEK_SET);
    }
    
    while (current > -1) {
        current -= sizeof(ISAEvent);
        fseek(_file, current, SEEK_SET);
        
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _fissionAlphaMaxTime) {
                if ([self isFront:event type:_startParticleType] && [self isFissionNearToFirstFissionFront:event]) {
                    [self storeNextFissionAlphaFront:event deltaTime:deltaTime];
                }
            } else {
                break;
            }
        }
    }
    
    fseek(_file, initial, SEEK_SET);
    
    // 2. Ищем в направлении до +_fissionMaxTime mks от T(Fission/Alpha First)
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        if (event.eventId == _dataProtocol.CycleTime) {
            _mainCycleTimeEvent = event;
        }
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _fissionAlphaMaxTime) {
                if ([self isFront:event type:_startParticleType] && [self isFissionNearToFirstFissionFront:event]) { // FFron/AFron пришедшие после первого
                    [self storeNextFissionAlphaFront:event deltaTime:deltaTime];
                }
            } else {
                return;
            }
        }
    }
}

/**
 Ищем все FWel/AWel в направлении до +_fissionAlphaMaxTime относительно времени T(Fission/Alpha First).
 */
- (void)findFissionsAlphaWel
{
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _fissionAlphaMaxTime) {
                if ([self isFissionOrAlphaWel:event]) {
                    [self storeFissionAlphaWell:event];
                }
            } else {
                return;
            }
        }
    }
}

- (unsigned long long)eventNumber
{
    fpos_t eventNumber;
    fgetpos(_file, &eventNumber);
    return (unsigned long long)eventNumber/sizeof(ISAEvent) + _totalEventNumber + 1;
}

- (void)storeFissionAlphaBack:(ISAEvent)event deltaTime:(int)deltaTime
{
    unsigned short encoder = [self fissionAlphaRecoilEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    double energy = [self getEnergy:event type:_startParticleType];
    NSDictionary *info = @{kEncoder:@(encoder),
                           kStrip0_15:@(strip_0_15),
                           kEnergy:@(energy),
                           kEventNumber:@([self eventNumber]),
                           kDeltaTime: @(deltaTime)};
    [_fissionsAlphaBackPerAct addObject:info];
}

- (BOOL)isGammaEvent:(ISAEvent)event
{
    return [_dataProtocol Gam:1] == event.eventId || [_dataProtocol Gam:2] == event.eventId || [_dataProtocol Gam] == event.eventId;
}

/**
 Ищем ВСЕ! Gam1 в окне до _maxGammaTime относительно времени Fission Front (в двух направлениях).
 */
- (void)findGamma
{
    fpos_t initial;
    fgetpos(_file, &initial);
    
    // 1. Ищем в направлении до -_maxGammaTime mks от T(Fission Front)
    fpos_t current = initial;
    while (current > -1) {
        current -= sizeof(ISAEvent);
        fseek(_file, current, SEEK_SET);
        
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _maxGammaTime) {
                if ([self isGammaEvent:event]) {
                    [self storeGamma:event deltaTime:deltaTime];
                }
            } else {
                break;
            }
        }
    }
    
    fseek(_file, initial, SEEK_SET);
    
    // 2. Ищем в направлении до +_maxGammaTime mks от T(Fission Front)
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
//#warning TODO: не учитывается EventIdCycleTime
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
            if (deltaTime <= _maxGammaTime) {
                if ([self isGammaEvent:event]) {
                    [self storeGamma:event deltaTime:deltaTime];
                }
            } else {
                return;
            }
        }
    }
}

- (void)storeGamma:(ISAEvent)event deltaTime:(int)deltaTime
{
    unsigned short channel = event.param3 & MaskGamma;
    double energy = [_calibration calibratedValueForAmplitude:channel eventName:@"Gam1"];
    NSDictionary *info = @{kEnergy:@(energy),
                           kDeltaTime: @(deltaTime)};
    [_gammaPerAct addObject:info];
}

/**
 У осколков/рекойлов записывается только время относительно начала нового счетчика времени (счетчик обновляется каждые 0xFFFF мкс).
 Для вычисления времени от запуска файла используем время цикла (id #24).
 */
- (long long)time:(unsigned short)relativeTime cycleEvent:(ISAEvent)cycleEvent
{
    return (((long long)cycleEvent.param3 << 16) + cycleEvent.param1) + relativeTime;
}

/**
 Поиск рекойла осуществляется с позиции файла где найден главный осколок/альфа (возвращаемся назад по времени).
 */
- (void)findRecoil
{
    long long fissionTime = [self time:_firstFissionAlphaTime cycleEvent:_mainCycleTimeEvent];
    ISAEvent cycleEvent = _mainCycleTimeEvent;
    
    fpos_t current;
    fgetpos(_file, &current);
//TODO: работает в пределах одного файла!
    while (current > -1) {
        current -= sizeof(ISAEvent);
        fseek(_file, current, SEEK_SET);
        
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        if (event.eventId == _dataProtocol.CycleTime) { // Откатились по времени к предыдущему циклу!
            cycleEvent = event;
        }
        
        if (NO == [self isValidEventIdForTimeCheck:event.eventId]) {
            continue;
        }
        
        long long recoilTime = [self time:event.param1 cycleEvent:cycleEvent];
        long double deltaTime = llabs((long long)recoilTime - fissionTime);
        if (deltaTime < _recoilMinTime) {
            continue;
        } else if (deltaTime <= _recoilMaxTime) {
            if (NO == [self isFront:event type:SearchTypeRecoil]) {
                continue;
            }
            
            double energy = [self getEnergy:event type:SearchTypeRecoil];
            if (energy < _recoilFrontMinEnergy || energy > _recoilFrontMaxEnergy) {
                continue;
            }
            
            if (NO == [self isEventFrontNearToFirstFissionAlphaFront:event maxDelta:_recoilFrontMaxDeltaStrips]) {
                continue;
            }
            
            // Сохраняем рекойл только если к нему найден Recoil Back
            BOOL isRecoilBackFounded = [self findRecoilBack:event.param1];
            fseek(_file, current, SEEK_SET);
            if (!isRecoilBackFounded) {
                continue;
            }
            
            BOOL isTOFFounded = [self findTOFForRecoil:event time:recoilTime];
            fseek(_file, current, SEEK_SET);
            if (_requiredTOF && !isTOFFounded) {
                continue;
            }

            [self storeRecoil:event deltaTime:deltaTime];
        } else {
            return;
        }
    }
}
    
- (void)storeRecoil:(ISAEvent)event deltaTime:(long long)deltaTime
{
    double energy = [self getEnergy:event type:SearchTypeRecoil];
    NSDictionary *info = @{kEnergy:@(energy),
                           kDeltaTime:@(deltaTime),
                           kEventNumber:@([self eventNumber])};
    [_recoilsFrontPerAct addObject:info];
}

/**
 Ищем Recoil Back в окне <= kFissionsMaxSearchTimeInMks относительно времени Recoil Front.
 */
- (BOOL)findRecoilBack:(unsigned short)timeRecoilFront
{
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        if (NO == [self isValidEventIdForTimeCheck:event.eventId]) {
            continue;
        }
        
        double deltaTime = fabs((double)event.param1 - timeRecoilFront);
        if (deltaTime <= _recoilBackMaxTime) {
            if ([self isBack:event type:SearchTypeRecoil]) {
                if (_requiredFissionRecoilBack) {
                    return [self isRecoilBackNearToFissionAlphaBack:event];
                }
                return YES;
            }
        } else {
            return NO;
        }
    }
    return NO;
}

/**
 Поиск альфы 2 осуществляется с позиции файла где найдена альфа 1 (вперед по времени).
 */
- (void)findAlpha2
{
    long long alphaTime = [self time:_firstFissionAlphaTime cycleEvent:_mainCycleTimeEvent];
    ISAEvent cycleEvent = _mainCycleTimeEvent;
    
    //  Ищем в направлении до +_maxAlpha2Time mks от T(Alpha 1 Front)
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        long long time = [self time:event.param1 cycleEvent:cycleEvent];
        long double deltaTime = llabs((long long)time - alphaTime);
        if (deltaTime < _alpha2MinTime) {
            continue;
        } else if (deltaTime <= _alpha2MaxTime) {
            if (NO == [self isFront:event type:SearchTypeAlpha]) {
                continue;
            }
            
            double energy = [self getEnergy:event type:SearchTypeAlpha];
            if (energy < _alpha2MinEnergy || energy > _alpha2MaxEnergy) {
                continue;
            }
            
            if (NO == [self isEventFrontNearToFirstFissionAlphaFront:event maxDelta:_alpha2MaxDeltaStrips]) {
                continue;
            }
            
            [self storeAlpha2:event deltaTime:deltaTime];
        } else {
            return;
        }
    }
}

- (void)storeAlpha2:(ISAEvent)event deltaTime:(long long)deltaTime
{
    double energy = [self getEnergy:event type:SearchTypeAlpha];
    NSDictionary *info = @{kEnergy:@(energy),
                           kDeltaTime:@(deltaTime),
                           kEventNumber:@([self eventNumber])};
    [_alpha2FrontPerAct addObject:info];
}

/**
 Real TOF for Recoil.
 */
- (BOOL)findTOFForRecoil:(ISAEvent)eventRecoil time:(unsigned short)timeRecoil
{
    fpos_t initial;
    fgetpos(_file, &initial);
    
    // 1. Ищем в направлении до -10 mks от T(Recoil)
    fpos_t current = initial;
    while (current > -1) {
        current -= sizeof(ISAEvent);
        fseek(_file, current, SEEK_SET);
        
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - timeRecoil);
            if (deltaTime <= _maxTOFTime) {
                if (_dataProtocol.TOF == event.eventId) {
                    double value = [self valueTOF:event forRecoil:eventRecoil];
                    if (value >= _minTOFValue && value <= _maxTOFValue) {
                        [self storeRealTOFValue:value deltaTime:-deltaTime];
                        return YES;
                    }
                }
            } else {
                break;
            }
        }
    }
    
    fseek(_file, initial, SEEK_SET);
    
    // 2. Ищем в направлении до +10 mks от T(Recoil)
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        if ([self isValidEventIdForTimeCheck:event.eventId]) {
            double deltaTime = fabs((double)event.param1 - timeRecoil);
            if (deltaTime <= _maxTOFTime) {
                if (_dataProtocol.TOF == event.eventId) {
                    double value = [self valueTOF:event forRecoil:eventRecoil];
                    if (value >= _minTOFValue && value <= _maxTOFValue) {
                        [self storeRealTOFValue:value deltaTime:deltaTime];
                        return YES;
                    }
                }
            } else {
                return NO;
            }
        }
    }
    
    return NO;
}

- (unsigned short)channelForTOF:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskTOF;
    return channel;
}

- (double)nanosecondsForTOFChannel:(unsigned short)channelTOF eventRecoil:(ISAEvent)eventRecoil
{
    unsigned short eventId = eventRecoil.eventId;
    unsigned short strip_0_15 = eventRecoil.param2 >> 12;  // value from 0 to 15
    unsigned short encoder = [self fissionAlphaRecoilEncoderForEventId:eventId];
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
    double channel = [self channelForTOF:eventTOF];
    if (_unitsTOF == TOFUnitsChannels) {
        return channel;
    } else {
        return [self nanosecondsForTOFChannel:channel eventRecoil:eventRecoil];
    }
}

- (void)storeRealTOFValue:(double)value deltaTime:(double)deltaTime
{
    NSDictionary *info = @{kValue:@(value),
                           kDeltaTime:@(deltaTime)};
    [_tofRealPerAct addObject:info];
}

static int const kTOFGenerationsMaxTime = 2; // from t(FF) (случайные генерации, а не отмеки рекойлов)
/**
 Поиск первых событий FON, Recoil Special, TOF (случайные генерации) осуществляется с позиции файла где найден главный осколок.
 */
- (void)findFONEvents
{
    BOOL fonFound = NO;
    BOOL recoilFound = NO;
    BOOL tofFound = NO;
    
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        
        if (_dataProtocol.FON == event.eventId) {
            if (!fonFound) {
                [self storeFON:event];
                fonFound = YES;
            }
        } else if (_dataProtocol.RecoilSpecial == event.eventId) {
            if (!recoilFound) {
                [self storeRecoilSpecial:event];
                recoilFound = YES;
            }
        } else if (_dataProtocol.TOF == event.eventId) {
            if (!tofFound) {
//#warning TODO: не учитывается EventIdCycleTime
                double deltaTime = fabs((double)event.param1 - _firstFissionAlphaTime);
                if (deltaTime <= kTOFGenerationsMaxTime) {
                    [self storeTOFGenerations:event];
                }
                tofFound = YES;
            }
        } else {
            continue;
        }
        
        if (fonFound && recoilFound && tofFound) {
            return;
        }
    }
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

- (void)storeNextFissionAlphaFront:(ISAEvent)event deltaTime:(double)deltaTime
{
    [self storeFissionAlphaFront:event isFirst:NO deltaTime:deltaTime];
}

- (void)storeFissionAlphaFront:(ISAEvent)event isFirst:(BOOL)isFirst deltaTime:(double)deltaTime
{
    unsigned short channel = (_startParticleType == SearchTypeFission) ? (event.param2 & MaskFission) : (event.param3 & MaskRecoilAlpha);
    unsigned short encoder = [self fissionAlphaRecoilEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    double energy = [self getEnergy:event type:_startParticleType];
    NSDictionary *info = @{kEncoder:@(encoder),
                           kStrip0_15:@(strip_0_15),
                           kChannel:@(channel),
                           kEnergy:@(energy),
                           kEventNumber:@([self eventNumber]),
                           kDeltaTime:@(deltaTime)};
    [_fissionsAlphaFrontPerAct addObject:info];
    
    if (isFirst) {
        unsigned short strip_1_48 = [self focalStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
        NSMutableDictionary *extraInfo = [info mutableCopy];
        [extraInfo setObject:@(strip_1_48) forKey:kStrip1_48];
        _firstFissionAlphaInfo = extraInfo;
        _firstFissionAlphaTime = event.param1;
    }
}

- (void)storeFissionAlphaWell:(ISAEvent)event
{
    double energy = [self getEnergy:event type:_startParticleType];
    unsigned short encoder = [self fissionAlphaRecoilEncoderForEventId:event.eventId];
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

/**
 Метод проверяет находится ли ! рекоил/альфа ! event на близких стрипах относительно первого осколка/альфы.
 */
- (BOOL)isEventFrontNearToFirstFissionAlphaFront:(ISAEvent)event maxDelta:(int)maxDelta
{
    unsigned short strip_0_15 = event.param2 >> 12;
    int strip_1_48 = [self focalStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
    int strip_1_48_first_fission = [[_firstFissionAlphaInfo objectForKey:kStrip1_48] intValue];
    return (abs(strip_1_48 - strip_1_48_first_fission) <= maxDelta);
}

/**
 Метод проверяет находится ли рекоил event на близких стрипах (_recoilBackMaxDeltaStrips) относительно заднего осколка с макимальной энергией.
 */
- (BOOL)isRecoilBackNearToFissionAlphaBack:(ISAEvent)event
{
    NSDictionary *fissionBackInfo = [self fissionAlphaBackWithMaxEnergyInAct];
    if (fissionBackInfo) {
        unsigned short strip_0_15 = event.param2 >> 12;
        int strip_1_48 = [self focalStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
        
        int strip_0_15_back_fission = [[fissionBackInfo objectForKey:kStrip0_15] intValue];
        int encoder_back_fission = [[fissionBackInfo objectForKey:kEncoder] intValue];
        int strip_1_48_back_fission = [self stripConvertToFormat_1_48:strip_0_15_back_fission encoder:encoder_back_fission];
        
        return (abs(strip_1_48 - strip_1_48_back_fission) <= _recoilBackMaxDeltaStrips);
    }
    return NO;
}

/**
 Метод проверяет находится ли осколок event на соседних стрипах относительно первого осколка.
 */
- (BOOL)isFissionNearToFirstFissionFront:(ISAEvent)event
{
    unsigned short strip_0_15 = event.param2 >> 12;
    
    int strip_0_15_first_fission = [[_firstFissionAlphaInfo objectForKey:kStrip0_15] intValue];
    if (strip_0_15 == strip_0_15_first_fission) { // совпадают
        return YES;
    }
    
    int strip_1_48 = [self focalStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
    int strip_1_48_first_fission = [[_firstFissionAlphaInfo objectForKey:kStrip1_48] intValue];
    return (abs(strip_1_48 - strip_1_48_first_fission) <= 1); // +/- 1 стрип
}

- (double)getEnergy:(ISAEvent)event type:(SearchType)type
{
    unsigned short channel = (type == SearchTypeFission) ? (event.param2 & MaskFission) : (event.param3 & MaskRecoilAlpha);
    unsigned short eventId = event.eventId;
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    unsigned short encoder = [self fissionAlphaRecoilEncoderForEventId:eventId];
    
    NSString *detector = nil;
    switch (type) {
        case SearchTypeFission:
            detector = @"F";
            break;
        case SearchTypeAlpha:
            detector = @"A";
            break;
        case SearchTypeRecoil:
            detector = @"R";
            break;
        default:
            break;
    }
    
    NSString *position = nil;
    if ([_dataProtocol AFron:1] == eventId || [_dataProtocol AFron:2] == eventId || [_dataProtocol AFron:3] == eventId) {
        position = @"Fron";
    } else if ([_dataProtocol ABack:1] == eventId || [_dataProtocol ABack:2] == eventId || [_dataProtocol ABack:3] == eventId) {
        position = @"Back";
    } else if ([_dataProtocol AdFr:1] == eventId || [_dataProtocol AdFr:2] == eventId || [_dataProtocol AdFr:3] == eventId) {
        position = @"dFr";
    } else if ([_dataProtocol AdBk:1] == eventId || [_dataProtocol AdBk:2] == eventId || [_dataProtocol AdBk:3] == eventId) {
        position = @"dBk";
    } else {
        position = @"Wel";
    }
    NSString *name = [NSString stringWithFormat:@"%@%@%d.%d", detector, position, encoder, strip_0_15+1];
    
    return [_calibration calibratedValueForAmplitude:channel eventName:name];
}

- (unsigned short)fissionAlphaRecoilEncoderForEventId:(unsigned short)eventId
{
    if ([_dataProtocol AFron:1] == eventId || [_dataProtocol ABack:1] == eventId || [_dataProtocol AdFr:1] == eventId || [_dataProtocol AdBk:1] == eventId || [_dataProtocol AWel:1] == eventId || [_dataProtocol AWel] == eventId) {
        return 1;
    }
    if ([_dataProtocol AFron:2] == eventId || [_dataProtocol ABack:2] == eventId || [_dataProtocol AdFr:2] == eventId || [_dataProtocol AdBk:2] == eventId || [_dataProtocol AWel:2] == eventId) {
        return 2;
    }
    if ([_dataProtocol AFron:3] == eventId || [_dataProtocol ABack:3] == eventId || [_dataProtocol AdFr:3] == eventId || [_dataProtocol AdBk:3] == eventId || [_dataProtocol AWel:3] == eventId) {
        return 3;
    }
    if ([_dataProtocol AWel:4] == eventId) {
        return 4;
    }
    return 0;
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

- (NSString *)currentFileEventNumber:(long long)number
{
    return [NSString stringWithFormat:@"%@_%llu", _currentFileName, number];
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
                            field = [self currentFileEventNumber:[eventNumberObject unsignedLongLongValue]];
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
                        field = [self currentFileEventNumber:eventNumber];
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
                        unsigned short strip = [self stripConvertToFormat_1_48:strip_0_15 encoder:encoder];
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
                        unsigned short strip = [self stripConvertToFormat_1_48:strip_0_15 encoder:encoder];
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
                            field = [self currentFileEventNumber:[event unsignedLongLongValue]];
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

/**
 В фокальном детекторе cтрипы подключены поочередно к трем 16-канальным кодировщикам:
 | 1.0 | 2.0 | 3.0 | 1.1 | 2.1 | 3.1 | 1.1 ... (encoder.strip_0_15)
 Метод переводит стрип из формата "кодировщик + стрип от 0 до 15" в формат "стрип от 1 до 48".
 */
- (unsigned short)focalStripConvertToFormat_1_48:(unsigned short)strip_0_15 eventId:(unsigned short)eventId
{
    int encoder = [self fissionAlphaRecoilEncoderForEventId:eventId];
    return [self stripConvertToFormat_1_48:strip_0_15 encoder:encoder];
}

- (unsigned short)stripConvertToFormat_1_48:(unsigned short)strip_0_15 encoder:(unsigned short)encoder
{
    return (strip_0_15 * 3) + (encoder - 1) + 1;
}

/**
 Не у всех событий в базе, вторые 16 бит слова отводятся под время.
 */
- (BOOL)isValidEventIdForTimeCheck:(unsigned short)eventId
{
    return (eventId <= [_dataProtocol AWel:2] || eventId <= [_dataProtocol AWel:1] || eventId <= [_dataProtocol AWel] || _dataProtocol.TOF == eventId || [_dataProtocol Gam:1] == eventId || [_dataProtocol Gam:2] == eventId || [_dataProtocol Gam] == eventId || _dataProtocol.Neutrons == eventId);
}

/**
 Чтобы различить рекоил и осколок/альфу используем первые 3 бита из param3:
 000 - осколок,
 100 - рекоил
 */
- (unsigned short)getMarker:(unsigned short)value_16_bits
{
    return (value_16_bits >> 13);
}

- (BOOL)isFront:(ISAEvent)event type:(SearchType)type
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    unsigned short typeMarker = (type == SearchTypeRecoil) ? kRecoilMarker : kFissionOrAlphaMarker;
    return (typeMarker == marker) && ([_dataProtocol AFron:1] == eventId || [_dataProtocol AFron:2] == eventId || [_dataProtocol AFron:3] == eventId || [_dataProtocol AdFr:1] == eventId || [_dataProtocol AdFr:2] == eventId || [_dataProtocol AdFr:3] == eventId);
}

- (BOOL)isFissionOrAlphaWel:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kFissionOrAlphaMarker == marker) && ([_dataProtocol AWel] == eventId || [_dataProtocol AWel:1] == eventId || [_dataProtocol AWel:2] == eventId || [_dataProtocol AWel:3] == eventId || [_dataProtocol AWel:4] == eventId);
}

- (BOOL)isBack:(ISAEvent)event type:(SearchType)type
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    unsigned short typeMarker = (type == SearchTypeRecoil) ? kRecoilMarker : kFissionOrAlphaMarker;
    return (typeMarker == marker) && ([_dataProtocol ABack:1] == eventId || [_dataProtocol ABack:2] == eventId || [_dataProtocol ABack:3] == eventId || [_dataProtocol AdBk:1] == eventId || [_dataProtocol AdBk:2] == eventId || [_dataProtocol AdBk:3] == eventId);
}

- (void)selectDataWithCompletion:(void (^)(BOOL))completion
{
    [DataLoader load:^(NSArray *files, Protocol *protocol){
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
