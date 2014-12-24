//
//  ISAFileManager.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 24.12.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISAFileManager : NSObject

+ (const char *)resultsFilePath;
+ (const char *)logsFilePath;
+ (const char *)multiplicityFilePath;
+ (const char *)calibrationFilePath;

@end
