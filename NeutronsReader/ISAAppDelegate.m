#import "ISAAppDelegate.h"
#import "ISACalibration.h"

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
@property (strong, nonatomic) NSMutableDictionary *neutronsMultiplicityTotal;
@property (strong, nonatomic) NSMutableArray *fissionsFrontPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsBackPerAct;
@property (strong, nonatomic) NSMutableArray *fissionsWelPerAct;
@property (strong, nonatomic) NSMutableArray *gammaPerAct;
@property (strong, nonatomic) NSMutableArray *tofPerAct;
@property (assign, nonatomic) BOOL isNewCycle;
@property (assign, nonatomic) unsigned short firstFissionTime;
@property (assign, nonatomic) int fissionBackSumm;
@property (assign, nonatomic) int fissionWel;
@property (assign, nonatomic) unsigned long long neutronsSummPerAct;
@property (strong, nonatomic) ISACalibration *calibration;

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
    
    for (NSString *path in self.selectedFiles) {
        FILE *file = fopen([path UTF8String], "rb");
        printf("\nFile: %s\n\n", [[path lastPathComponent] UTF8String]);
        if (file == NULL) {
            exit(-1);
        } else {
            while (!feof(file)) {
                ISAEvent event;
                fread(&event, sizeof(event), 1, file);
                
                BOOL isFFront = [self isFissionFront:event];
                double deltaTime = fabs(event.param1 - _firstFissionTime);
                
                // Завершаем цикл если прошло слишком много времени, с момента запуска.
                if (_isNewCycle && (deltaTime > kNeutronMaxSearchTimeInMks) && [self isValidEventIdForTimeCheck:event.eventId]) {
                    
                    // Определение суммарной множественности нейтронов во всех файлах
                    unsigned long long summ = [[_neutronsMultiplicityTotal objectForKey:@(_neutronsSummPerAct)] unsignedLongLongValue];
                    summ += 1; // Одно событие для всех нейтронов в одном акте деления
                    [_neutronsMultiplicityTotal setObject:@(summ) forKey:@(_neutronsSummPerAct)];
                    
                    [self closeCycle];
                }
                
#warning TODO: суммируем осколки с лицевой стороны в пределах 5 мкс
                if (isFFront) {
                    // Запускаем новый цикл поиска, только если энергия осколка на лицевой стороне детектора выше установленной.
                    unsigned short channel = event.param2 & kFissionMask;
                    unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
                    unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
                    unsigned short strip_1_16 = strip_0_15 + 1; // value from 1 to 16
                    
                    double energy = [self getFissionEnegry:event];
                    if (energy >= [_sMinEnergy doubleValue]) {
                        NSDictionary *fissionInfo = @{@"encoder":@(encoder),
                                                      @"strip":@(strip_1_16),
                                                      @"channel":@(channel),
                                                      @"energy":@(energy)};
                        [_fissionsFrontPerAct addObject:fissionInfo];
                        _firstFissionTime = event.param1;
                        _isNewCycle = YES;
                    }
                    
                    continue;
                }
                
                BOOL isFBack = [self isFissionBack:event];
                BOOL isFWel = [self isFissionWel:event];
                if ((isFBack || isFWel) && _isNewCycle && (deltaTime <= kFissionsMaxSearchTimeInMks)) {
                    // Осколки с тыльной стороны фокального детектора
                    if (isFBack) {
                        unsigned short encoder = [self fissionEncoderForEventId:event.eventId];
                        unsigned short strip_0_15 = event.param2 >> 12;  // value from 0 to 15
                        unsigned short strip_1_16 = strip_0_15 + 1; // value from 1 to 16
                        
                        NSDictionary *fissionInfo = @{@"encoder":@(encoder),
                                                      @"strip":@(strip_1_16)};
                        [_fissionsBackPerAct addObject:fissionInfo];
                        continue;
                    }
                    
                    // Осколки в боковых детекторах
                    if (isFWel) {
                        double energy = [self getFissionEnegry:event];
                        [_fissionsWelPerAct addObject:@(energy)];
                        
                        continue;
                    }
                }
                
                // Определение множественности нейтронов в акте деления
                BOOL isNeutron = (kNeutrons == event.eventId);
                if (isNeutron && _isNewCycle && (deltaTime <= kNeutronMaxSearchTimeInMks)) {
                    _neutronsSummPerAct += 1;
                    
                    continue;
                }
                
                // Гамма-кванты
                BOOL isGamma = (kGam1 == event.eventId);
                if (isGamma && _isNewCycle && (deltaTime <= kGammaMaxSearchTimeInMks)) {
                    unsigned short channel = event.param3 & kGamMask;
                    double energy = [_calibration energyForAmplitude:channel ofEvent:@"Gam1"];
                    
                    [_gammaPerAct addObject:@(energy)];
                    
                    continue;
                }
                
                // TOF рекойлов
                BOOL isTOF = (kTOF == event.eventId);
                if (isTOF && _isNewCycle && (deltaTime <= kTOFMaxSearchTimeInMks)) {
                    unsigned short channel = event.param3 & kTOFMask;
                    [_tofPerAct addObject:@(channel)];
                    
                    continue;
                }
                
                // Достигли конца последнего файла.
                if (feof(file) && [[self.selectedFiles lastObject] isEqualTo:path] && _isNewCycle) {
                    [self closeCycle];
                }
            }
        }
        fclose(file);
    }
    
    [self logTotalMultiplicity];
    
    [self.activity stopAnimation:self];
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

- (void)closeCycle
{
    // Выводим результаты для акта деления
    [self logActResults];
    
    // Обнуляем все данные для акта
    _neutronsSummPerAct = 0;
    [_fissionsFrontPerAct removeAllObjects];
    [_fissionsBackPerAct removeAllObjects];
    [_gammaPerAct removeAllObjects];
    [_tofPerAct removeAllObjects];
    [_fissionsWelPerAct removeAllObjects];
    
    _isNewCycle = NO;
}

//TODO: вывод в виде таблицы
- (void)logActResults
{
    for (NSDictionary *fissionInfo in _fissionsFrontPerAct) {
        printf("FFron%d.%d\t\t%f MeV (%d channel)\n", [[fissionInfo objectForKey:@"encoder"] intValue], [[fissionInfo objectForKey:@"strip"] intValue], [[fissionInfo objectForKey:@"energy"] doubleValue], [[fissionInfo objectForKey:@"channel"] intValue]);
    }
    
    printf("Neutrons\t%llu\n", _neutronsSummPerAct);
    
    if ([_gammaPerAct count]) {
        for (NSNumber *energy in _gammaPerAct) {
            printf("Gam1\t\t%f MeV\n", [energy doubleValue]);
        }
    }
    
    if ([_fissionsWelPerAct count]) {
        for (NSNumber *energy in _fissionsWelPerAct) {
            printf("FWel\t\t%f MeV\n", [energy doubleValue]);
        }
    }
    
    for (NSDictionary *fissionInfo in _fissionsBackPerAct) {
        printf("FBack%d.%d\n", [[fissionInfo objectForKey:@"encoder"] intValue], [[fissionInfo objectForKey:@"strip"] intValue]);
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

#warning TODO: будет применяться при определении близжайших осколков в фокальном детекторе
/**
 В фокальном детекторе, стрипы поочередно выводятся на 3 разных 16-канальных кодировщика.
 */
- (unsigned short)focalFissionStrip48Format:(unsigned short)strip16Format eventId:(unsigned short)eventId
{
    int encoder = 0;
    if (kFFont2 == eventId || kFBack2 == eventId) {
        encoder = 1;
    } else if (kFFont3 == eventId || kFBack3 == eventId) {
        encoder = 2;
    }
    return (strip16Format * 3) + encoder;
}

/**
 Не у всех событий в базе, вторые 16 бит слова отводятся под время.
 */
- (BOOL)isValidEventIdForTimeCheck:(unsigned short)eventId
{
    return (kFFont1 == eventId || kFFont2 == eventId || kFFont3 == eventId || kNeutrons == eventId);
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
        if ([[openPanel URLs] count]) {
//            printf("Selected files:\n");
        }
        for (NSURL *url in [openPanel URLs]) {
            NSString *path = [url path];
            
            BOOL isDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
                NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
                // Исключаем файл протокола из выборки
                NSArray *dataFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"!(self ENDSWITH '.PRO') AND !(self ENDSWITH '.DS_Store')"]];
//                for (NSString *fileName in dataFiles) {
//                    NSString *filePath = [path stringByAppendingPathComponent:fileName];
//                    printf("\n%s", [filePath UTF8String]);
//                    [self.selectedFiles addObject:filePath];
//                }
            } else {
//                printf("\n%s", [path UTF8String]);
                [self.selectedFiles addObject:path];
            }
        }
//        printf("\n\n");
    }
}

@end

