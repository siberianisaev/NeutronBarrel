#import "ISAAppDelegate.h"
#import "ISACalibration.h"

static int const kNeutronMaxSearchTimeInMks = 130; // from t(FF) to t(last neutron)
static int const kFissionsMaxSearchTimeInMks = 3; // from t(FF1) to t(FF2)
static unsigned short kFissionMinEnergy = 500; // FBack or FFront channel
static unsigned short kFFont1 = 1;
static unsigned short kFFont2 = 2;
static unsigned short kFFont3 = 3;
static unsigned short kFBack1 = 4;
static unsigned short kFBack2 = 5;
static unsigned short kFBack3 = 6;
static unsigned short kFWel1 = 7;
static unsigned short kFWel2 = 8;
static unsigned short kGam1 = 10;
static unsigned short kGam2 = 11;
static unsigned short kNeutrons = 18;
static unsigned short kFissionMask = 0x0FFF;
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
@property (strong, nonatomic) NSMutableDictionary *multiplicity;
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
    
    self.multiplicity = [NSMutableDictionary dictionary];
    
    for (NSString *path in self.selectedFiles) {
        FILE *file = fopen([path UTF8String], "rb");
        if (file == NULL) {
            exit(-1);
        } else {
            while (!feof(file)) {
                ISAEvent event;
                fread(&event, sizeof(event), 1, file);
                
                BOOL isFFront = [self isFissionFront:event];
                BOOL isNeutron = (kNeutrons == event.eventId);
                
                double deltaTime =  fabs(event.param1 - self.firstFissionTime);
                
                // Завершаем цикл если прошло слишком много времени, с момента запуска.
                if (_isNewCycle && (deltaTime > kNeutronMaxSearchTimeInMks) && [self isValidEventIdForTimeCheck:event.eventId]) {
                    
                    unsigned long long summ = [[self.multiplicity objectForKey:@(self.neutronsSummPerAct)] unsignedLongLongValue];
                    summ += 1; // Одно событие для всех нейтронов в одном акте деления
                    [self.multiplicity setObject:@(summ) forKey:@(self.neutronsSummPerAct)];
                    
                    self.neutronsSummPerAct = 0;
                    _isNewCycle = NO;
                }
                
                if (isFFront) {
                    // Запускаем новый цикл поиска, только если энергия осколка на лицевой стороне детектора выше установленной.
                    unsigned short channel = event.param2 & kFissionMask;
                    
                    unsigned short eventId = event.eventId;
                    unsigned short strip = event.param2 >> 12;
                    NSString *name = [NSString stringWithFormat:@"FFron%d.%d", eventId, strip];
                    NSInteger energy = [_calibration energyForAmplitude:channel ofEvent:name];
                    if (energy >= [_sMinEnergy intValue]) {
                        self.firstFissionTime = event.param1;
                        _isNewCycle = YES;
                    }
                    
                    continue;
                }
                
                // Инкрементируем в пределах одного цикла.
                if (isNeutron && _isNewCycle && (deltaTime <= kNeutronMaxSearchTimeInMks)) {
                    self.neutronsSummPerAct += 1;
                    
                    continue;
                }
            }
        }
        fclose(file);
    }
    
    [self logResults];
    
    [self.activity stopAnimation:self];
}

- (void)logResults
{
    printf("Neutrons multiplicity\n");
    for (NSString *key in [self.multiplicity.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSNumber *value = [self.multiplicity objectForKey:key];
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

