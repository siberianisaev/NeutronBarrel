//
//  ISAEventStack.h
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.11.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISAEventStack : NSObject

+ (instancetype)stack;

- (NSArray *)events;
- (void)setMaxSize:(NSUInteger)maxSize;
- (void)pushEvent:(NSValue *)eventValue;
- (void)clear;

@end
