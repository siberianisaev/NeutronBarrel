//
//  ISAProcessor.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISAProcessor.h"

static int const kTOFForRecoilMaxSearchTimeInMks = 10; // +/- from t(Recoil)
static int const kRecoilMaxSearchTimeInMks = 400; // from t(FF) to t(Recoil) - backward search
static int const kNeutronMaxSearchTimeInMks = 132; // from t(FF) to t(last neutron)
static int const kGammaMaxSearchTimeInMks = 5; // from t(FF) to t(last gamma)
static int const kTOFMaxSearchTimeInMks = 2; // from t(FF) (случайные генерации, а не отмеки рекойлов)
static int const kFONMaxSearchTimeInMks = 1000000; // from t(FF) (в интервале <= 1 секунда)
static int const kFissionsMaxSearchTimeInMks = 5; // from t(FF1) to t(FF2)

/**
 Маркер отличающий осколок (0) от рекойла (4), записывается в первые 3 бита param3.
 */
static unsigned short kFissionMarker = 0b000;
static unsigned short kRecoilMarker = 0b100;

static NSString * const kEncoder = @"encoder";
static NSString * const kStrip0_15 = @"strip_0_15";
static NSString * const kStrip1_48 = @"strip_1_48";
static NSString * const kEnergy = @"energy";
static NSString * const kDeltaTime = @"delta_time";
static NSString * const kChannel = @"channel";
static NSString * const kEventNumber = @"event_number";

typedef struct {
    unsigned short eventId;
    unsigned short param1;
    unsigned short param2;
    unsigned short param3;
} ISAEvent;

typedef NS_ENUM(unsigned short, EventId) {
    EventIdFissionFront1 = 1,
    EventIdFissionFront2 = 2,
    EventIdFissionFront3 = 3,
    EventIdFissionBack1 = 4,
    EventIdFissionBack2 = 5,
    EventIdFissionBack3 = 6,
    EventIdFissionWell1 = 13,
    EventIdFissionWell2 = 14,
    EventIdGamma1 = 15,
    EventIdTOF = 17,
    EventIdNeutrons = 23,
    EventIdFON = 29,
    EventIdTrigger = 30
};

typedef NS_ENUM(unsigned short, Mask) {
    MaskFission = 0x0FFF,
    MaskGamma = 0x1FFF,
    MaskTOF = 0x1FFF,
    MaskFON = 0xFFFF,
    MaskTrigger = 0xFFFF
};

@interface ISAProcessor ()

@property (strong, nonatomic) Calibration *calibration;
@property (strong, nonatomic) NSArray *selectedFiles;
@property (strong, nonatomic) NSString *currentFileName;
@property (assign, nonatomic) unsigned long long currentEventNumber;
@property (strong, nonatomic) NSMutableDictionary *neutronsMultiplicityTotal;
@property (strong, nonatomic) NSMutableArray *fissionsFrontPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsBackPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsWelPerAct;
@property (strong, nonatomic) NSMutableArray *gammaPerAct;
@property (strong, nonatomic) NSMutableArray *tofPerAct;
@property (strong, nonatomic) NSNumber *fonPerAct;
@property (strong, nonatomic) NSNumber *trigerPerAct;
@property (strong, nonatomic) NSNumber *tofForRecoilPerAct;
@property (strong, nonatomic) NSDictionary *recoilFrontInfo;
@property (strong, nonatomic) NSDictionary *firstFissionInfo; // информация о главном осколке в цикле
@property (assign, nonatomic) unsigned short firstFissionTime; // время главного осколка в цикле
@property (assign, nonatomic) int fissionBackSumm;
@property (assign, nonatomic) int fissionWel;
@property (assign, nonatomic) unsigned long long neutronsSummPerAct;
@property (assign, nonatomic) BOOL isNewAct;
@property (assign, nonatomic) FILE *file;
@property (strong, nonatomic) EventStack *fissionsFrontNotInCycleStack; // осколки пришедшие до обнаружения главного осколка (стек нужен для возврата к нескольким предыдущем событиям по времени)
@property (strong, nonatomic) EventStack *gammaNotInCycleStack; // гамма-кванты пришедшие до обнаружения главного осколка (стек нужен для возврата к нескольким предыдущем событиям по времени)

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
#warning TODO: загружать дефолтную только если не была добавлена с помощью Open Panel (nil)!
        _calibration = [Calibration defaultCalibration];
        _selectedFiles = [NSArray array];
    }
    return self;
}

- (void)processData
{
    _neutronsMultiplicityTotal = [NSMutableDictionary dictionary];
    _fissionsFrontPerAct = [NSMutableArray array];
    _fissionsBackPerAct = [NSMutableArray array];
    _gammaPerAct = [NSMutableArray array];
    _tofPerAct = [NSMutableArray array];
    _fissionsWelPerAct = [NSMutableArray array];
    _fissionsFrontNotInCycleStack = [EventStack new];
    _gammaNotInCycleStack = [EventStack new];
    
    const char *resultsFileName = [FileManager resultsFilePath].UTF8String;
    FILE *outputFile = fopen(resultsFileName, "w");
    if (outputFile == NULL) {
        printf("Error opening file %s\n", resultsFileName);
        exit(1);
    }
    fprintf(outputFile, "File\tEvent\tE(RFron)\tdT(RFron-FFron)\tSumm(FFron)\tStrip(FFron)\tStrip(FBack)\tFWel\tFWelPos\tNeutrons\tGamma\tFON\tTriger\n\n");
    
    for (NSString *path in self.selectedFiles) {
        _file = fopen([path UTF8String], "rb");
        _currentFileName = [path lastPathComponent];
        _currentEventNumber = 0;
        printf("Processed %s\n", [_currentFileName UTF8String]);
        if (_file == NULL) {
            exit(-1);
        } else {
            setvbuf(_file, NULL, _IONBF, 0); // disable buffering
            while (!feof(_file)) {
                ISAEvent event;
                fread(&event, sizeof(event), 1, _file);
                _currentEventNumber += 1;
                
                double deltaTime = fabs(event.param1 - _firstFissionTime);
                
                // Завершаем цикл если прошло слишком много времени, с момента запуска.
                if (_isNewAct && (deltaTime > kNeutronMaxSearchTimeInMks) && [self isValidEventIdForTimeCheck:event.eventId]) {
                    [self actStoped:outputFile];
                }
                
                // Gam1 Backward Search
                if ((NO == _isNewAct) && (EventIdGamma1 == event.eventId)) {
                    [self storePreviousGamma:event];
                    continue;
                }
                
                // FFron
                if ([self isFissionFront:event]) {
                    if (NO == _isNewAct) {
                        // Запускаем новый цикл поиска, только если энергия осколка на лицевой стороне детектора выше минимальной
                        if ([self getFissionEnergy:event] >= self.fissionFrontMinEnergy) {
                            [self actStartedWithEvent:event];
                            
                            fpos_t position;
                            fgetpos(_file, &position);
                            // Recoil
                            [self findRecoil];
                            // FON
                            [self findFONEvent];
                            // Triger
                            [self findTrigerEvent];
                            fseek(_file, position, SEEK_SET);
                        } else {  // FFron пришедшие до первого
                            [self storePreviousFissionFront:event];
                        }
                    } else if (deltaTime <= kFissionsMaxSearchTimeInMks && [self isNearToFirstFissionFront:event]) { // FFron пришедшие после первого
                        [self storeNextFissionFront:event];
                    }
                    
                    continue;
                }
                
                if (NO == _isNewAct) {
                    continue;
                }
                
                // FBack
                if ([self isFissionBack:event] && (deltaTime <= kFissionsMaxSearchTimeInMks)) {
                    [self storeFissionBack:event];
                    continue;
                }
                
                // FWel
                if ([self isFissionWel:event] && (deltaTime <= kFissionsMaxSearchTimeInMks)) {
                    [self storeFissionWell:event];
                    continue;
                }
                
                // Gam1
                if ((EventIdGamma1 == event.eventId) && (deltaTime <= kGammaMaxSearchTimeInMks)) {
                    [self storeGamma:event];
                    continue;
                }
                
                // TOF
                if ((EventIdTOF == event.eventId) && (deltaTime <= kTOFMaxSearchTimeInMks)) {
                    [self storeTOF:event];
                    continue;
                }
                
                // Neutrons
                if ((EventIdNeutrons == event.eventId) && (deltaTime <= kNeutronMaxSearchTimeInMks)) {
                    _neutronsSummPerAct += 1;
                    continue;
                }
                
                // End of last file.
                if (feof(_file) && [[self.selectedFiles lastObject] isEqualTo:path]) {
                    [self actStoped:outputFile];
                }
            }
        }
        fclose(_file);
    }
    
    fclose(outputFile);
    [Logger logMultiplicity:_neutronsMultiplicityTotal];
}

/**
 Поиск рекойла осуществляется с позиции файла где найден главный осколок (возвращаемся назад по времени).
 Время поиска <= 400 мкс.
 */
- (void)findRecoil
{
    fpos_t current;
    fgetpos(_file, &current);
    while (current > -1) {
        current -= sizeof(ISAEvent);
        fseek(_file, current, SEEK_SET);
        
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
        double deltaTime = fabs(event.param1 - _firstFissionTime);
        if (deltaTime <= kRecoilMaxSearchTimeInMks) {
            if ([self isRecoilFront:event]) {
                NSDictionary *firstFissionInfo = [_fissionsFrontPerAct firstObject];
                unsigned short encoder = [self fissionEncoderForEventId:event.eventId]; // Кодировщик определяется так же как для Fission
                if (encoder != [[firstFissionInfo valueForKey:kEncoder] integerValue]) { // Один и тот же кодировщик
                    continue;
                }
                
                unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
                if (strip_0_15 != [[firstFissionInfo valueForKey:kStrip0_15] integerValue]) { // На одном стрипе
                    continue;
                }
                
                [self storeRecoil:event deltaTime:deltaTime];
#warning TODO: find TOF +/- 10 mks
                return;
            }
        } else {
            return;
        }
    }
}
    
- (void)storeRecoil:(ISAEvent)event deltaTime:(unsigned long long)deltaTime
{
    double energy = [self getRecoilEnergy:event];
    _recoilFrontInfo = @{kEnergy:@(energy),
                         kDeltaTime:@(deltaTime)};
}

/**
 Поиск первого события FON осуществляется с позиции файла где найден главный осколок.
 Время поиска <= 1 секунды.
 */
- (void)findFONEvent
{
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
#warning TODO: учитывать старшие разряды времени THi !
        //            double deltaTime = fabs(event.param1 - _firstFissionTime);
        //            if ((kFON == event.eventId) && (deltaTime <= kFONMaxSearchTimeInMks)) {
        if (EventIdFON == event.eventId) {
            [self storeFON:event];
            return;
        }
    }
}

/**
 Поиск первого события Triger осуществляется с позиции файла где найден главный осколок.
 Время поиска <= 1 секунды.
 */
- (void)findTrigerEvent
{
    while (!feof(_file)) {
        ISAEvent event;
        fread(&event, sizeof(event), 1, _file);
#warning TODO: учитывать старшие разряды времени THi !
        //            double deltaTime = fabs(event.param1 - _firstFissionTime);
        //            if ((kTriger == event.eventId) && (deltaTime <= kTrigerMaxSearchTimeInMks)) {
        if (EventIdTrigger == event.eventId) {
            [self storeTriger:event];
            return;
        }
    }
}

- (void)storeFON:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskFON;
    _fonPerAct = @(channel);
}

- (void)storeTriger:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskTrigger;
    _trigerPerAct = @(channel);
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

- (void)storeFirstFissionFront:(ISAEvent)event
{
    [self storeFissionFront:event isFirst:YES];
}

- (void)storePreviousFissionFront:(ISAEvent)event
{
    NSValue *value = [NSValue valueWithBytes:&event objCType:@encode(ISAEvent)];
    [_fissionsFrontNotInCycleStack pushEvent:value];
}

- (void)storePreviousGamma:(ISAEvent)event
{
    NSValue *value = [NSValue valueWithBytes:&event objCType:@encode(ISAEvent)];
    [_gammaNotInCycleStack pushEvent:value];
}

- (void)storeNextFissionFront:(ISAEvent)event
{
    [self storeFissionFront:event isFirst:NO];
}

- (void)storeFissionFront:(ISAEvent)event isFirst:(BOOL)isFirst
{
    unsigned short channel = event.param2 & MaskFission;
    unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    double energy = [self getFissionEnergy:event];
    NSDictionary *fissionInfo = @{kEncoder:@(encoder),
                                  kStrip0_15:@(strip_0_15),
                                  kChannel:@(channel),
                                  kEnergy:@(energy),
                                  kEventNumber:@(_currentEventNumber)};
    [_fissionsFrontPerAct addObject:fissionInfo];
    
    if (isFirst) {
        unsigned short strip_1_48 = [self focalFissionStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
        NSMutableDictionary *extraInfo = [fissionInfo mutableCopy];
        [extraInfo setObject:@(strip_1_48) forKey:kStrip1_48];
        _firstFissionInfo = extraInfo;
        _firstFissionTime = event.param1;
    }
}

- (void)storeFissionBack:(ISAEvent)event
{
    unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    double energy = [self getFissionEnergy:event];
    NSDictionary *fissionInfo = @{kEncoder:@(encoder),
                                  kStrip0_15:@(strip_0_15),
                                  kEnergy:@(energy),
                                  kEventNumber:@(_currentEventNumber)};
    [_fissionsBackPerAct addObject:fissionInfo];
}

- (void)storeFissionWell:(ISAEvent)event
{
    double energy = [self getFissionEnergy:event];
    unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    NSDictionary *fissionInfo = @{kEncoder:@(encoder),
                                  kStrip0_15:@(strip_0_15),
                                  kEnergy:@(energy)};
    [_fissionsWelPerAct addObject:fissionInfo];
}

- (void)storeGamma:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskGamma;
    double energy = [_calibration energyForAmplitude:channel eventName:@"Gam1"];
    [_gammaPerAct addObject:@(energy)];
}

- (void)storeTOF:(ISAEvent)event
{
    unsigned short channel = event.param3 & MaskTOF;
    [_tofPerAct addObject:@(channel)];
}

/**
 Метод проверяет находится ли осколок event на соседних стрипах относительно первого осколка.
 */
- (BOOL)isNearToFirstFissionFront:(ISAEvent)event
{
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    
    int strip_0_15_first_fission = [[_firstFissionInfo objectForKey:kStrip0_15] intValue];
    if (strip_0_15 == strip_0_15_first_fission) { // совпадают
        return YES;
    }
    
    int strip_1_48 = [self focalFissionStripConvertToFormat_1_48:strip_0_15 eventId:event.eventId];
    int strip_1_48_first_fission = [[_firstFissionInfo objectForKey:kStrip1_48] intValue];
    return (abs(strip_1_48 - strip_1_48_first_fission) <= 1); // +/- 1 стрип
}

/**
 Анализируем стек осколков с конца, если осколок близкий по времени и по позиции первому осколку (триггеру цикла), то сохраняем его в _fissionsFrontPerAct.
 */
- (void)analyzeOldFissions
{
    for (NSValue *value in [_fissionsFrontNotInCycleStack.events reverseObjectEnumerator]) {
        ISAEvent event;
        [value getValue:&event];
        
        double deltaTime = fabs(event.param1 - _firstFissionTime);
        if (deltaTime <= kFissionsMaxSearchTimeInMks) {
            if ([self isNearToFirstFissionFront:event]) {
                [self storeNextFissionFront:event];
            }
        } else { // Далее в цикле пойдут слишком удаленные по времени события
            break;
        }
    }
    [_fissionsFrontNotInCycleStack clear];
}

/**
 Анализируем стек гамма-квантов с конца, если гамма-квант близкий по времени первому осколку (триггеру цикла), то сохраняем его в _gammaPerAct.
 */
- (void)analyzeOldGamma
{
    for (NSValue *value in [_gammaNotInCycleStack.events reverseObjectEnumerator]) {
        ISAEvent event;
        [value getValue:&event];
        
#warning TODO: создать структуру для записи firstFissionTime в виде THi + TLo и уточнить обработку данных для old событий! (THi1 == THi2)
        double deltaTime = fabs(event.param1 - _firstFissionTime);
        if (deltaTime <= kGammaMaxSearchTimeInMks) {
            [self storeGamma:event];
        } else { // Далее в цикле пойдут слишком удаленные по времени события
            break;
        }
    }
    [_gammaNotInCycleStack clear];
}

- (double)getFissionEnergy:(ISAEvent)event
{
    return [self getFissionOrRecoilEnergy:event isFission:YES];
}
    
- (double)getRecoilEnergy:(ISAEvent)event
{
    return [self getFissionOrRecoilEnergy:event isFission:NO];
}

- (double)getFissionOrRecoilEnergy:(ISAEvent)event isFission:(BOOL)isFission
{
    unsigned short channel = event.param2 & MaskFission;
    unsigned short eventId = event.eventId;
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    unsigned short encoder = [self fissionEncoderForEventId:eventId];
    
    NSString *sFissionOrRecoil = isFission ? @"F" : @"R";
    NSString *detector = nil;
    if (EventIdFissionFront1 == eventId || EventIdFissionFront2 == eventId || EventIdFissionFront3 == eventId) {
        detector = @"Fron";
    } else if (EventIdFissionBack1 == eventId || EventIdFissionBack2 == eventId || EventIdFissionBack3 == eventId) {
        detector = @"Back";
    } else {
        detector = @"Wel";
    }
    NSString *name = [NSString stringWithFormat:@"%@%@%d.%d", sFissionOrRecoil, detector, encoder, strip_0_15+1];
    
    return [_calibration energyForAmplitude:channel eventName:name];
}

- (unsigned short)fissionEncoderForEventId:(unsigned short)eventId
{
    if (EventIdFissionFront1 == eventId || EventIdFissionBack1 == eventId || EventIdFissionWell1 == eventId) {
        return 1;
    }
    if (EventIdFissionFront2 == eventId || EventIdFissionBack2 == eventId || EventIdFissionWell2 == eventId) {
        return 2;
    }
    if (EventIdFissionFront3 == eventId || EventIdFissionBack3 == eventId) {
        return 3;
    }
    return 0;
}

- (void)actStartedWithEvent:(ISAEvent)event
{
    [self storeFirstFissionFront:event];
    [self analyzeOldFissions];
    [self analyzeOldGamma];
    _isNewAct = YES;
}

- (void)actStoped:(FILE *)outputFile
{
    [self updateNeutronsMultiplicity];
    [self logActResults:outputFile];
    [self clearActInfo];
    _isNewAct = NO;
}

- (void)clearActInfo
{
    _neutronsSummPerAct = 0;
    [_fissionsFrontPerAct removeAllObjects];
    [_fissionsBackPerAct removeAllObjects];
    [_gammaPerAct removeAllObjects];
    [_tofPerAct removeAllObjects];
    [_fissionsWelPerAct removeAllObjects];
    _firstFissionInfo = nil;
    _fonPerAct = nil;
    _trigerPerAct = nil;
    _recoilFrontInfo = nil;
}

- (void)logActResults:(FILE *)outputFile
{
    // FFRON
    unsigned long long eventNumber = NAN;
    double summFFronE = 0;
    int stripFFronEMax = -1;
    double maxFFronE = 0;
    for (NSDictionary *fissionInfo in _fissionsFrontPerAct) {
        double energy = [[fissionInfo objectForKey:kEnergy] doubleValue];
        if (maxFFronE < energy) {
            maxFFronE = energy;
            
            int strip_0_15 = [[fissionInfo objectForKey:kStrip0_15] intValue];
            int encoder = [[fissionInfo objectForKey:kEncoder] intValue];
            stripFFronEMax = [self focalFissionStripConvertToFormat_1_48:strip_0_15 encoder:encoder];
            
            eventNumber = [[fissionInfo objectForKey:kEventNumber] unsignedLongLongValue];
        }
        summFFronE += energy;
    }
    
    // FBACK
    int stripFBackChannelMax = -1;
    double maxFBackE = 0;
    for (NSDictionary *fissionInfo in _fissionsBackPerAct) {
        double energy = [[fissionInfo objectForKey:kEnergy] doubleValue];
        if (maxFBackE < energy) {
            maxFBackE = energy;
            
            int strip_0_15 = [[fissionInfo objectForKey:kStrip0_15] intValue];
            int encoder = [[fissionInfo objectForKey:kEncoder] intValue];
            stripFBackChannelMax = [self focalFissionStripConvertToFormat_1_48:strip_0_15 encoder:encoder];
        }
    }
    
    NSMutableString *result = [NSMutableString string];
    int columnsCount = 12;
    int rowsMax = MAX(MAX(1, (int)_gammaPerAct.count), (int)_fissionsWelPerAct.count);
    for (int row = 0; row < rowsMax; row++) {
        for (int column = 0; column <= columnsCount; column++) {
            switch (column) {
                case 0:
                {
                    if (row == 0) {
                        [result appendString:_currentFileName];
                    }
                    break;
                }
                case 1:
                {
                    if (row == 0) {
                        [result appendFormat:@"%7.llu", eventNumber];
                    }
                    break;
                }
                case 2:
                {
                    NSNumber *recoilEnergy = [_recoilFrontInfo valueForKey:kEnergy];
                    if (row == 0 && recoilEnergy) {
                        [result appendFormat:@"%4.7f", [recoilEnergy doubleValue]];
                    }
                    break;
                }
                case 3:
                {
                    NSNumber *deltaTimeRecoilFission = [_recoilFrontInfo valueForKey:kDeltaTime];
                    if (row == 0 && deltaTimeRecoilFission) {
                        [result appendFormat:@"%6llu", (unsigned long long)[deltaTimeRecoilFission unsignedLongLongValue]];
                    }
                    break;
                }
                case 4:
                {
                    if (row == 0) {
                        [result appendFormat:@"%4.7f", summFFronE];
                    }
                    break;
                }
                case 5:
                {
                    if (row == 0 && stripFFronEMax > 0) {
                        [result appendFormat:@"%2d", stripFFronEMax];
                    }
                    break;
                }
                case 6:
                {
                    if (row == 0 && stripFBackChannelMax > 0) {
                        [result appendFormat:@"%2d", stripFBackChannelMax];
                    }
                    break;
                }
                case 7:
                {
                    if (row < (int)_fissionsWelPerAct.count) {
                        NSDictionary *fissionInfo = [_fissionsWelPerAct objectAtIndex:row];
                        [result appendFormat:@"%4.7f", [[fissionInfo objectForKey:kEnergy] doubleValue]];
                    }
                    break;
                }
                case 8:
                {
                    if (row < (int)_fissionsWelPerAct.count) {
                        NSDictionary *fissionInfo = [_fissionsWelPerAct objectAtIndex:row];
                        [result appendFormat:@"FWel%d.%d", [[fissionInfo objectForKey:kEncoder] intValue], [[fissionInfo objectForKey:kStrip0_15] intValue]+1];
                    }
                    break;
                }
                case 9:
                {
                    if (row == 0) {
                        [result appendFormat:@"%2llu", _neutronsSummPerAct];
                    }
                    break;
                }
                case 10:
                {
                    if (row < (int)_gammaPerAct.count) {
                        [result appendFormat:@"%4.7f", [[_gammaPerAct objectAtIndex:row] doubleValue]];
                    }
                    break;
                }
                case 11:
                {
                    if (row == 0 && _fonPerAct) {
                        [result appendFormat:@"%hu", [_fonPerAct unsignedShortValue]];
                    }
                    break;
                }
                case 12:
                {
                    if (row == 0 && _trigerPerAct) {
                        [result appendFormat:@"%hu", [_trigerPerAct unsignedShortValue]];
                    }
                    break;
                }
                default:
                    break;
            }
            [result appendString:@"\t"];
            if (column == columnsCount) {
                [result appendString:@"\n"];
            }
        }
    }
    fprintf(outputFile, "%s", [result UTF8String]);
}

/**
 В фокальном детекторе cтрипы подключены поочередно к трем 16-канальным кодировщикам:
 | 1.0 | 2.0 | 3.0 | 1.1 | 2.1 | 3.1 | 1.1 ... (encoder.strip_0_15)
 Метод переводит стрип из формата "кодировщик + стрип от 0 до 15" в формат "стрип от 1 до 48".
 */
- (unsigned short)focalFissionStripConvertToFormat_1_48:(unsigned short)strip_0_15 eventId:(unsigned short)eventId
{
    int encoder = 1;
    if (EventIdFissionFront2 == eventId || EventIdFissionBack2 == eventId) {
        encoder = 2;
    } else if (EventIdFissionFront3 == eventId || EventIdFissionBack3 == eventId) {
        encoder = 3;
    }
    return [self focalFissionStripConvertToFormat_1_48:strip_0_15 encoder:encoder];
}

- (unsigned short)focalFissionStripConvertToFormat_1_48:(unsigned short)strip_0_15 encoder:(unsigned short)encoder
{
    return (strip_0_15 * 3) + (encoder - 1) + 1;
}

/**
 Не у всех событий в базе, вторые 16 бит слова отводятся под время.
 */
- (BOOL)isValidEventIdForTimeCheck:(unsigned short)eventId
{
    return (eventId <= EventIdFissionWell2 || EventIdGamma1 == eventId || EventIdNeutrons == eventId);
}

/**
 Чтобы различить рекоил и осколок используем первые 3 бита из param3:
 000 - осколок,
 100 - рекоил
 */
- (unsigned short)getMarker:(unsigned short)value_16_bits
{
    return (value_16_bits >> 13);
}

- (BOOL)isFissionFront:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kFissionMarker == marker) && (EventIdFissionFront1 == eventId || EventIdFissionFront2 == eventId || EventIdFissionFront3 == eventId);
}

- (BOOL)isFissionWel:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kFissionMarker == marker) && (EventIdFissionWell1 == eventId || EventIdFissionWell2 == eventId);
}

- (BOOL)isFissionBack:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kFissionMarker == marker) && (EventIdFissionBack1 == eventId || EventIdFissionBack2 == eventId || EventIdFissionBack3 == eventId);
}

- (BOOL)isRecoilFront:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kRecoilMarker == marker) && (EventIdFissionFront1 == eventId || EventIdFissionFront2 == eventId || EventIdFissionFront3 == eventId);
}

- (void)selectData
{
    [DataLoader load:^(NSArray *files){
        self.selectedFiles = files;
    }];
}

- (void)selectCalibration
{
    [Calibration openCalibration:^(Calibration *calibration){
         self.calibration = calibration;
    }];
}

@end
