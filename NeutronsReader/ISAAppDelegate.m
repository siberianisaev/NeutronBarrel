#import "ISAAppDelegate.h"
#import "ISAProcessor.h"

@interface ISAAppDelegate ()

@property (copy, nonatomic) NSString *sMinEnergy;
@property (weak) IBOutlet NSProgressIndicator *activity;

- (IBAction)start:(id)sender;
- (IBAction)selectData:(id)sender;
- (IBAction)selectCalibration:(id)sender;

@end

@implementation ISAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.sMinEnergy = [NSString stringWithFormat:@"%d", kDefaultFissionFrontMinEnergy];
}

- (IBAction)start:(id)sender
{
    [self.activity startAnimation:self];
    ISAProcessor *processor = [ISAProcessor processor];
    processor.fissionFrontMinEnergy = _sMinEnergy.doubleValue;
    [processor processData];
    [self.activity stopAnimation:self];
}

- (IBAction)selectData:(id)sender
{
    [[ISAProcessor processor] selectData];
}

- (IBAction)selectCalibration:(id)sender
{
    [[ISAProcessor processor] selectCalibration];
}

@end

