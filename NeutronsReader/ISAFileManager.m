//
//  ISAFileManager.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISAFileManager.h"

@implementation ISAFileManager

+ (NSString *)desktopFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES);
    NSString *desktopPath = [paths objectAtIndex:0];
    return desktopPath;
}

+ (const char *)desktopFilePathWithName:(NSString *)fileName
{
    NSString *desktopPath = [self desktopFolder];
    NSString *resultsPath = [desktopPath stringByAppendingPathComponent:fileName];
    return [resultsPath UTF8String];
}

+ (const char *)resultsFilePath
{
    return [self desktopFilePathWithName:@"results.txt"];
}

+ (const char *)logsFilePath
{
    return [self desktopFilePathWithName:@"logs.txt"];
}

+ (const char *)multiplicityFilePath
{
    return [self desktopFilePathWithName:@"multiplicity.txt"];
}

+ (const char *)calibrationFilePath
{
    return [self desktopFilePathWithName:@"calibration.txt"];
}

@end
