//
//  ISALogger.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISALogger.h"
#import "ISAFileManager.h"

@implementation ISALogger

+ (void)logString:(NSString *)string toPath:(const char *)path
{
    FILE *file = fopen(path, "w");
    if (file == NULL) {
        printf("Error opening file %s\n", path);
        exit(1);
    }
    
    fprintf(file, "%s", [string UTF8String]);
    
    fclose(file);
}

+ (void)logMultiplicity:(NSDictionary *)info
{
    const char *fileName = [ISAFileManager multiplicityFilePath];
    
    NSMutableString *string = [NSMutableString stringWithString:@"Neutrons multiplicity\n"];
    for (NSString *key in [info.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSNumber *value = [info objectForKey:key];
        [string appendFormat:@"%d-x: %llu\n", [key intValue], [value unsignedLongLongValue]];
    }
    
    [self logString:string toPath:fileName];
}

+ (void)logCalibration:(NSString *)string
{
    const char *fileName = [ISAFileManager calibrationFilePath];
    [self logString:string toPath:fileName];
}

@end
