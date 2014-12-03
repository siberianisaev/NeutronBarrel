#import "ISAAppDelegate.h"
#import "ISACalibration.h"
#import "ISAEventStack.h"

static int const kNeutronMaxSearchTimeInMks = 132; // from t(FF) to t(last neutron)
static int const kGammaMaxSearchTimeInMks = 5; // from t(FF) to t(last gamma)
static int const kTOFMaxSearchTimeInMks = 2; // from t(FF) (случайные генерации, а не отмеки рекойлов)
static int const kFissionsMaxSearchTimeInMks = 5; // from t(FF1) to t(FF2)
static unsigned short kFissionMinEnergy = 20; // FBack or FFront MeV
static unsigned short kFFont1 = 1;
static unsigned short kFFont2 = 2;
static unsigned short kFFont3 = 3;
static unsigned short kFBack1 = 4;
static unsigned short kFBack2 = 5;
static unsigned short kFBack3 = 6;
static unsigned short kFWel1 = 7;
static unsigned short kFWel2 = 8;
static unsigned short kGam1 = 10; // Gamma-detector ID
static unsigned short kTOF = 12;
static unsigned short kNeutrons = 18;
static unsigned short kFissionMask = 0x0FFF;
static unsigned short kGamMask = 0x1FFF;
static unsigned short kTOFMask = 0x1FFF;
static unsigned short kFissionMarker = 0; // !Recoil

typedef struct {
    unsigned short eventId;
    unsigned short param1;
    unsigned short param2;
    unsigned short param3;
} ISAEvent;

@interface ISAAppDelegate ()

@property (strong, nonatomic) NSMutableArray *selectedFiles;
@property (copy, nonatomic) NSString *sMinEnergy;
@property (weak) IBOutlet NSProgressIndicator *activity;
@property (strong, nonatomic) NSString *currentFileName;
@property (assign, nonatomic) unsigned long long currentEventNumber;
@property (strong, nonatomic) NSMutableDictionary *neutronsMultiplicityTotal;
@property (strong, nonatomic) NSMutableArray *fissionsFrontPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsBackPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsWelPerAct;
@property (strong, nonatomic) NSMutableArray *gammaPerAct;
@property (strong, nonatomic) NSMutableArray *tofPerAct;
@property (strong, nonatomic) NSDictionary *firstFissionInfo; // информация о главном осколке в цикле
@property (assign, nonatomic) unsigned short firstFissionTime; // время главного осколка в цикле
@property (assign, nonatomic) int fissionBackSumm;
@property (assign, nonatomic) int fissionWel;
@property (assign, nonatomic) unsigned long long neutronsSummPerAct;
@property (assign, nonatomic) BOOL isNewAct;
@property (strong, nonatomic) ISACalibration *calibration;
@property (strong, nonatomic) ISAEventStack *fissionsFrontNotInCycleStack; // осколки пришедшие до обнаружения главного осколка (стек нужен для возврата к нескольким предыдущем событиям по времени)

@end

@implementation ISAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _sMinEnergy = [NSString stringWithFormat:@"%d", kFissionMinEnergy];
    _selectedFiles = [NSMutableArray array];
    [self loadCalibration];
}

- (void)loadCalibration
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"clb"];
    NSURL *url = [NSURL fileURLWithPath:path];
//TODO: use open panel
    _calibration = [ISACalibration calibrationWithUrl:url];
}

- (IBAction)start:(id)sender
{
    [self.activity startAnimation:self];
    
    _neutronsMultiplicityTotal = [NSMutableDictionary dictionary];
    _fissionsFrontPerAct = [NSMutableArray array];
    _fissionsBackPerAct = [NSMutableArray array];
    _gammaPerAct = [NSMutableArray array];
    _tofPerAct = [NSMutableArray array];
    _fissionsWelPerAct = [NSMutableArray array];
    _fissionsFrontNotInCycleStack = [ISAEventStack stack];
    
    for (NSString *path in self.selectedFiles) {
        FILE *file = fopen([path UTF8String], "rb");
        _currentFileName = [path lastPathComponent];
        _currentEventNumber = 0;
        printf("\nFile: %s\n\n", [_currentFileName UTF8String]);
        if (file == NULL) {
            exit(-1);
        } else {
            while (!feof(file)) {
                ISAEvent event;
                fread(&event, sizeof(event), 1, file);
                _currentEventNumber += 1;
                
                double deltaTime = fabs(event.param1 - _firstFissionTime);
                
                // Завершаем цикл если прошло слишком много времени, с момента запуска.
                if (_isNewAct && (deltaTime > kNeutronMaxSearchTimeInMks) && [self isValidEventIdForTimeCheck:event.eventId]) {
                    [self actStoped];
                }
                
                // FFron
                if ([self isFissionFront:event]) {
                    if (NO == _isNewAct) {
                        // Запускаем новый цикл поиска, только если энергия осколка на лицевой стороне детектора выше минимальной
                        if ([self getFissionEnegry:event] >= [_sMinEnergy doubleValue]) {
                            [self actStartedWithEvent:event];
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
                if ((kGam1 == event.eventId) && (deltaTime <= kGammaMaxSearchTimeInMks)) {
                    [self storeGamma:event];
                    continue;
                }
                
                // TOF
                if ((kTOF == event.eventId) && (deltaTime <= kTOFMaxSearchTimeInMks)) {
                    [self storeTOF:event];
                    continue;
                }
                
                // Neutrons
                if ((kNeutrons == event.eventId) && (deltaTime <= kNeutronMaxSearchTimeInMks)) {
                    _neutronsSummPerAct += 1;
                    continue;
                }
                
                // End of last file.
                if (feof(file) && [[self.selectedFiles lastObject] isEqualTo:path]) {
                    [self actStoped];
                }
            }
        }
        fclose(file);
    }
    
    [self logTotalMultiplicity];
    
    [self.activity stopAnimation:self];
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

- (void)storeNextFissionFront:(ISAEvent)event
{
    [self storeFissionFront:event isFirst:NO];
}

- (void)storeFissionFront:(ISAEvent)event isFirst:(BOOL)isFirst
{
    unsigned short channel = event.param2 & kFissionMask;
    unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    unsigned short strip_1_16 = strip_0_15 + 1; // value from 1 to 16
    
    double energy = [self getFissionEnegry:event];
    NSDictionary *fissionInfo = @{@"encoder":@(encoder),
                                  @"strip_1_16":@(strip_1_16),
                                  @"channel":@(channel),
                                  @"energy":@(energy),
                                  @"event_number":@(_currentEventNumber)};
    [_fissionsFrontPerAct addObject:fissionInfo];
    
    if (isFirst) {
        unsigned short strip_1_48 = [self focalFissionStripConvertToFormat_1_48:strip_1_16 eventId:event.eventId];
        NSMutableDictionary *extraInfo = [fissionInfo mutableCopy];
        [extraInfo setObject:@(strip_1_48) forKey:@"strip_1_48"];
        _firstFissionInfo = extraInfo;
        _firstFissionTime = event.param1;
    }
}

- (void)storeFissionBack:(ISAEvent)event
{
    unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    unsigned short strip_1_16 = strip_0_15 + 1; // value from 1 to 16
    
    NSDictionary *fissionInfo = @{@"encoder":@(encoder),
                                  @"strip_1_16":@(strip_1_16),
                                  @"event_number":@(_currentEventNumber)};
    [_fissionsBackPerAct addObject:fissionInfo];
}

- (void)storeFissionWell:(ISAEvent)event
{
    double energy = [self getFissionEnegry:event];
    [_fissionsWelPerAct addObject:@(energy)];
}

- (void)storeGamma:(ISAEvent)event
{
    unsigned short channel = event.param3 & kGamMask;
    double energy = [_calibration energyForAmplitude:channel ofEvent:@"Gam1"];
    NSDictionary *gammaInfo = @{@"energy":@(energy),
                                @"event_number":@(_currentEventNumber)};
    [_gammaPerAct addObject:gammaInfo];
}

- (void)storeTOF:(ISAEvent)event
{
    unsigned short channel = event.param3 & kTOFMask;
    [_tofPerAct addObject:@(channel)];
}

/**
 Метод проверяет находится ли осколок event на соседних стрипах относительно первого осколка.
 */
- (BOOL)isNearToFirstFissionFront:(ISAEvent)event
{
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    unsigned short strip_1_16 = strip_0_15 + 1; // value from 1 to 16
    
    int strip_1_16_first_fission = [[_firstFissionInfo objectForKey:@"strip_1_16"] intValue];
    if (strip_1_16 == strip_1_16_first_fission) { // совпадают
        return YES;
    }
    
    int strip_1_48 = [self focalFissionStripConvertToFormat_1_48:strip_1_16 eventId:event.eventId];
    int strip_1_48_first_fission = [[_firstFissionInfo objectForKey:@"strip_1_48"] intValue];
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

- (double)getFissionEnegry:(ISAEvent)event
{
    unsigned short channel = event.param2 & kFissionMask;
    unsigned short eventId = event.eventId;
    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
    unsigned short strip_1_16 = strip_0_15 + 1; // value from 1 to 16
    unsigned short encoder = [self fissionEncoderForEventId:eventId];
    
    NSString *prefix = nil;
    if (kFFont1 == eventId || kFFont2 == eventId || kFFont3 == eventId) {
        prefix = @"FFron";
    } else if (kFBack1 == eventId || kFBack2 == eventId || kFBack3 == eventId) {
        prefix = @"FBack";
    } else {
        prefix = @"FWel";
    }
    NSString *name = [NSString stringWithFormat:@"%@%d.%d", prefix, encoder, strip_1_16];
    
    return [_calibration energyForAmplitude:channel ofEvent:name];
}

- (unsigned short)fissionEncoderForEventId:(unsigned short)eventId
{
    if (kFFont1 == eventId || kFBack1 == eventId || kFWel1 == eventId) {
        return 1;
    }
    if (kFFont2 == eventId || kFBack2 == eventId || kFWel2 == eventId) {
        return 2;
    }
    if (kFFont3 == eventId || kFBack3 == eventId) {
        return 3;
    }
    return 0;
}

- (void)actStartedWithEvent:(ISAEvent)event
{
    [self storeFirstFissionFront:event];
    [self analyzeOldFissions];
    _isNewAct = YES;
}

- (void)actStoped
{
    [self updateNeutronsMultiplicity];
    [self logActResults];
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
}

//TODO: вывод в виде таблицы
- (void)logActResults
{
    [self logActResultsToFile];
//    [self logActResultsToConsole];
}

#warning TODO: log to file
- (void)logActResultsToFile
{
    // FFRON
    unsigned long long eventNumber = NAN;
    double summFFronE = 0;
    double stripFFronEMax = NAN;
    double maxFFronE = 0;
    for (NSDictionary *fissionInfo in _fissionsFrontPerAct) {
        double energy = [[fissionInfo objectForKey:@"energy"] doubleValue];
        if (maxFFronE < energy) {
            maxFFronE = energy;
            
            int strip = [[fissionInfo objectForKey:@"strip_1_16"] intValue];
            int encoder = [[fissionInfo objectForKey:@"encoder"] intValue];
            stripFFronEMax = [self focalFissionStripConvertToFormat_1_48:strip encoder:encoder];
            
            eventNumber = [[fissionInfo objectForKey:@"event_number"] unsignedLongLongValue];
        }
        summFFronE += energy;
    }
    
    // FBACK
    double stripFBackEMax = NAN;
    double maxFBackE = 0;
    for (NSDictionary *fissionInfo in _fissionsBackPerAct) {
        double energy = [[fissionInfo objectForKey:@"energy"] doubleValue];
        if (maxFBackE < energy) {
            maxFBackE = energy;
            
            int strip = [[fissionInfo objectForKey:@"strip_1_16"] intValue];
            int encoder = [[fissionInfo objectForKey:@"encoder"] intValue];
            stripFBackEMax = [self focalFissionStripConvertToFormat_1_48:strip encoder:encoder];
        }
    }
    
    int rowsMax = MAX(MAX(1, (int)_gammaPerAct.count), (int)_fissionsWelPerAct);
    for (int column = 0; column < 8; column++) {
        for (int row = 0; row < rowsMax; row++) {
            // FILE INFO
            if (column == 0) {
                if (row == 0) {
                    printf("%s", [_currentFileName UTF8String]);
                } else {
                    for (int i = 0; i < _currentFileName.length; i++) {
                        printf(" ");
                    }
                }
                printf("\t");
            }
            
            // FFRON
            if (column == 1) {
                if (row == 0) {
                    printf("%f", summFFronE);
                } else {
                    printf("   ");
                }
                printf("\t");
            }
            
            #warning TODO;
        }
    }
    
    
//    printf("∑FFron\t\t%f MeV\n", summFFron);
//    
//    printf("Neutrons\t%llu\n", _neutronsSummPerAct);
//    
//    if ([_gammaPerAct count]) {
//        for (NSDictionary *gammaInfo in _gammaPerAct) {
//            NSNumber *energy = [gammaInfo objectForKey:@"energy"];
//            printf("Gam1\t\t%f MeV\n", [energy doubleValue]);
//        }
//    }
//    
//    if ([_fissionsWelPerAct count]) {
//        for (NSNumber *energy in _fissionsWelPerAct) {
//            printf("FWel\t\t%f MeV\n", [energy doubleValue]);
//        }
//    }
//    
//    for (NSDictionary *fissionInfo in _fissionsBackPerAct) {
//        printf("FBack%d.%d\n", [[fissionInfo objectForKey:@"encoder"] intValue], [[fissionInfo objectForKey:@"strip_1_16"] intValue]);
//    }
//    
//    if ([_tofPerAct count]) {
//        for (NSNumber *channel in _tofPerAct) {
//            printf("TOF\t\t%d channel\n", [channel intValue]);
//        }
//    }
//    
//    printf("\n");
}

- (void)logActResultsToConsole
{
    double summFFron = 0;
    for (NSDictionary *fissionInfo in _fissionsFrontPerAct) {
        double energy = [[fissionInfo objectForKey:@"energy"] doubleValue];
        printf("FFron%d.%d\t\t%f MeV", [[fissionInfo objectForKey:@"encoder"] intValue], [[fissionInfo objectForKey:@"strip_1_16"] intValue], energy);
        if (energy >= [_sMinEnergy doubleValue]) {
            printf(" (%d channel)", [[fissionInfo objectForKey:@"channel"] intValue]);
        }
        printf("\n");
        summFFron += energy;
    }
    printf("∑FFron\t\t%f MeV\n", summFFron);
    
    printf("Neutrons\t%llu\n", _neutronsSummPerAct);
    
    if ([_gammaPerAct count]) {
        for (NSDictionary *gammaInfo in _gammaPerAct) {
            NSNumber *energy = [gammaInfo objectForKey:@"energy"];
            printf("Gam1\t\t%f MeV\n", [energy doubleValue]);
        }
    }
    
    if ([_fissionsWelPerAct count]) {
        for (NSNumber *energy in _fissionsWelPerAct) {
            printf("FWel\t\t%f MeV\n", [energy doubleValue]);
        }
    }
    
    for (NSDictionary *fissionInfo in _fissionsBackPerAct) {
        printf("FBack%d.%d\n", [[fissionInfo objectForKey:@"encoder"] intValue], [[fissionInfo objectForKey:@"strip_1_16"] intValue]);
    }
    
    if ([_tofPerAct count]) {
        for (NSNumber *channel in _tofPerAct) {
            printf("TOF\t\t%d channel\n", [channel intValue]);
        }
    }
    
    printf("\n");
}

- (void)logTotalMultiplicity
{
    printf("Neutrons multiplicity\n");
    for (NSString *key in [_neutronsMultiplicityTotal.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSNumber *value = [_neutronsMultiplicityTotal objectForKey:key];
        printf("%d-x: %llu\n", [key intValue], [value unsignedLongLongValue]);
    }
}

/**
 В фокальном детекторе cтрипы подключены поочередно к трем 16-канальным кодировщикам:
 | 1.1 | 2.1 | 3.1 | 1.2 | 2.2 | 3.2 | 1.3 ... (encoder.strip)
 Метод переводит стрип из формата "кодировщик + стрип от 1 до 16" в формат "стрип от 1 до 48".
 */
- (unsigned short)focalFissionStripConvertToFormat_1_48:(unsigned short)strip_1_16 eventId:(unsigned short)eventId
{
    int encoder = 1;
    if (kFFont2 == eventId || kFBack2 == eventId) {
        encoder = 2;
    } else if (kFFont3 == eventId || kFBack3 == eventId) {
        encoder = 3;
    }
    return [self focalFissionStripConvertToFormat_1_48:strip_1_16 encoder:encoder];
}

- (unsigned short)focalFissionStripConvertToFormat_1_48:(unsigned short)strip_1_16 encoder:(unsigned short)encoder
{
    return (strip_1_16 * 3) + (encoder - 1);
}

/**
 Не у всех событий в базе, вторые 16 бит слова отводятся под время.
 */
- (BOOL)isValidEventIdForTimeCheck:(unsigned short)eventId
{
    return (eventId <= kFWel2 || kGam1 == eventId || kNeutrons == eventId);
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
    return (kFissionMarker == marker) && (kFFont1 == eventId || kFFont2 == eventId || kFFont3 == eventId);
}

- (BOOL)isFissionWel:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kFissionMarker == marker) && (kFWel1 == eventId || kFWel2 == eventId);
}

- (BOOL)isFissionBack:(ISAEvent)event
{
    unsigned short eventId = event.eventId;
    unsigned short marker = [self getMarker:event.param3];
    return (kFissionMarker == marker) && (kFBack1 == eventId || kFBack2 == eventId || kFBack3 == eventId);
}

- (IBAction)select:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:YES];
    
    if (NSOKButton == [openPanel runModal]) {
//        if ([[openPanel URLs] count]) {
//            printf("Selected files:\n");
//        }
        for (NSURL *url in [openPanel URLs]) {
            NSString *path = [url path];
            
            BOOL isDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
                NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
                // Исключаем файл протокола из выборки
                NSArray *dataFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"!(self ENDSWITH '.PRO') AND !(self ENDSWITH '.DS_Store')"]];
                for (NSString *fileName in dataFiles) {
                    NSString *filePath = [path stringByAppendingPathComponent:fileName];
//                    printf("\n%s", [filePath UTF8String]);
                    [self.selectedFiles addObject:filePath];
                }
            } else {
//                printf("\n%s", [path UTF8String]);
                [self.selectedFiles addObject:path];
            }
        }
//        printf("\n\n");
    }
}

@end

