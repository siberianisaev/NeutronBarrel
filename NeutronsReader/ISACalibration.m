//
//  ISACalibration.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 26.11.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISACalibration.h"

static NSString * const kName = @"kName";
static NSString * const kCoefficientA = @"kCoefficientA";
static NSString * const kCoefficientB = @"kCoefficientB";

@interface ISACalibration ()

@property (strong, nonatomic) NSMutableDictionary *data;

@end

@implementation ISACalibration

+ (instancetype)calibrationWithUrl:(NSURL *)url
{
    ISACalibration *calibration = [ISACalibration new];
    [calibration load:url];
    return calibration;
}

- (void)load:(NSURL *)url
{
    self.data = [NSMutableDictionary dictionary];
    
    NSString *path = [url path];
    printf("\nCALIBRATION\n----------\nLoad calibration from file: %s\n(B)\t\t(A)\t\t(Name)\n", [[path lastPathComponent] UTF8String]);
    
    NSError __autoreleasing *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    content = [content stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    if (nil == error) {
        NSCharacterSet *setSpaces = [NSCharacterSet whitespaceCharacterSet];
        NSCharacterSet *setLines = [NSCharacterSet newlineCharacterSet];
        NSArray *lines = [content componentsSeparatedByCharactersInSet:setLines];
        for (NSString *line in lines) {
            NSMutableArray *components = [[line componentsSeparatedByCharactersInSet:setSpaces] mutableCopy];
            [components removeObject:@""];
            if (3 == [components count]) {
                CGFloat b = [[components objectAtIndex:0] floatValue];
                CGFloat a = [[components objectAtIndex:1] floatValue];
                NSString *name = [components objectAtIndex:2];
                printf("%.6f\t%.6f\t%s\n", b, a, [name UTF8String]);
                
                [self.data setObject:@{kCoefficientB:@(b), kCoefficientA:@(a)} forKey:name];
            }
        }
        printf("----------\n");
    } else {
        NSLog(@"%@", error);
    }
}

- (double)energyForAmplitude:(unsigned short)channel ofEvent:(NSString *)name
{
    NSDictionary *value = [self.data objectForKey:name];
    NSNumber *nB = [value objectForKey:kCoefficientB];
    NSNumber *nA = [value objectForKey:kCoefficientA];
    if (nil == value || nil == nB || nil == nA) {
        [NSException raise:@"No calibration for name!" format:@"%@", name];
    }
    
    return [nB doubleValue] + [nA doubleValue] * (double)channel;
}

@end
