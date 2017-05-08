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
    [_processor logInput];
    [_processor logCalibration];
    [_processor logResultsHeader];
    
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
                        [strongSelf.processor mainCycleEventCheck:event];
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
