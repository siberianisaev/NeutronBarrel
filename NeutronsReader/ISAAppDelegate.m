#import "ISAAppDelegate.h"
#import "ISACalibration.h"

static int const kNeutronMaxSearchTimeInMks = 132; // from t(FF) to t(last neutron)
static int const kGammaMaxSearchTimeInMks = 5; // from t(FF) to t(last gamma)
static int const kFissionsMaxSearchTimeInMks = 3; // from t(FF1) to t(FF2)
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
static unsigned short kNeutrons = 18;
static unsigned short kFissionMask = 0x0FFF;
static unsigned short kGamMask = 0x1FFF;
static unsigned short kNeutronsTimeMask = 0x007F;
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
@property (strong, nonatomic) NSMutableArray *gammaEnergiesPerAct;
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
    _gammaEnergiesPerAct = [NSMutableArray array];
    
    for (NSString *path in self.selectedFiles) {
        FILE *file = fopen([path UTF8String], "rb");
        if (file == NULL) {
            exit(-1);
        } else {
            while (!feof(file)) {
                ISAEvent event;
                fread(&event, sizeof(event), 1, file);
                
                BOOL isFFront = [self isFissionFront:event];
                
                
                double deltaTime =  fabs(event.param1 - _firstFissionTime);
                
                // Завершаем цикл если прошло слишком много времени, с момента запуска.
                if (_isNewCycle && (deltaTime > kNeutronMaxSearchTimeInMks) && [self isValidEventIdForTimeCheck:event.eventId]) {
                    
                    // Определение суммарной множественности нейтронов во всех файлах
                    unsigned long long summ = [[_neutronsMultiplicityTotal objectForKey:@(_neutronsSummPerAct)] unsignedLongLongValue];
                    summ += 1; // Одно событие для всех нейтронов в одном акте деления
                    [_neutronsMultiplicityTotal setObject:@(summ) forKey:@(_neutronsSummPerAct)];
                    
                    // Выводим результаты для акта деления
                    [self logActResults];
                    
                    // Обнуляем все данные для акта
                    _neutronsSummPerAct = 0;
                    [_fissionsFrontPerAct removeAllObjects];
                    [_gammaEnergiesPerAct removeAllObjects];
                    _isNewCycle = NO;
                }
                
#warning TODO: суммируем осколки с лицевой стороны в пределах 5 мкс
                if (isFFront) {
                    // Запускаем новый цикл поиска, только если энергия осколка на лицевой стороне детектора выше установленной.
                    unsigned short channel = event.param2 & kFissionMask;
                    unsigned short eventId = event.eventId;
                    unsigned short strip = event.param2 >> 12;
#warning TODO: правильное определение стрипа в 48 стриповом детекторе (чередуются для каждого кодировщика!), на основе event id !
                    strip += 1;
                    
                    NSString *name = [NSString stringWithFormat:@"FFron%d.%d", eventId, strip];
                    double energy = [_calibration energyForAmplitude:channel ofEvent:name];
                    if (energy >= [_sMinEnergy doubleValue]) {
                        NSDictionary *fissionInfo = @{@"id":@(eventId), @"strip":@(strip), @"energy":@(energy)};
                        [_fissionsFrontPerAct addObject:fissionInfo];
                        _firstFissionTime = event.param1;
                        _isNewCycle = YES;
                    }
                    
                    continue;
                }
                
                // Определение множественности нейтронов в акте деления
                BOOL isNeutron = (kNeutrons == event.eventId);
                if (isNeutron && _isNewCycle && (deltaTime <= kNeutronMaxSearchTimeInMks)) {
                    _neutronsSummPerAct += 1;
                    
                    continue;
                }
                
                BOOL isGamma = (kGam1 == event.eventId);
                if (isGamma && _isNewCycle && (deltaTime <= kGammaMaxSearchTimeInMks)) {
                    unsigned short channel = event.param3 & kGamMask;
                    double energy = [_calibration energyForAmplitude:channel ofEvent:@"Gam1"];
                    
                    [_gammaEnergiesPerAct addObject:@(energy)];
                    
                    continue;
                }
            }
        }
        fclose(file);
    }
    
    [self logTotalMultiplicity];
    
    [self.activity stopAnimation:self];
}

//TODO: вывод в виде таблицы
- (void)logActResults
{
    for (NSDictionary *fissionInfo in _fissionsFrontPerAct) {
        printf("FFRON%d.%d\n", [[fissionInfo objectForKey:@"id"] intValue], [[fissionInfo objectForKey:@"strip"] intValue]);
        printf("%f MeV\n", [[fissionInfo objectForKey:@"energy"] doubleValue]);
    }
    
    printf("Neutrons %llu\n", _neutronsSummPerAct);
    
    if ([_gammaEnergiesPerAct count]) {
        printf("GAM1\n");
        for (NSNumber *energy in _gammaEnergiesPerAct) {
            printf("%f MeV\n", [energy doubleValue]);
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

- (IBAction)select:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:YES];
    
    if (NSOKButton == [openPanel runModal]) {
        if ([[openPanel URLs] count]) {
            printf("Selected files:\n");
        }
        for (NSURL *url in [openPanel URLs]) {
            NSString *path = [url path];
            
            BOOL isDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
                NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
                // Исключаем файл протокола из выборки
                NSArray *dataFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"!(self ENDSWITH '.PRO') AND !(self ENDSWITH '.DS_Store')"]];
                for (NSString *fileName in dataFiles) {
                    NSString *filePath = [path stringByAppendingPathComponent:fileName];
                    printf("\n%s", [filePath UTF8String]);
                    [self.selectedFiles addObject:filePath];
                }
            } else {
                printf("\n%s", [path UTF8String]);
                [self.selectedFiles addObject:path];
            }
        }
        printf("\n");
    }
}

@end

