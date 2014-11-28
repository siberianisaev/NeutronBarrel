//
//  ISAEventStack.m
//  NeutronsReader
//
//  Created by Andrey Isaev on 27.11.14.
//  Copyright (c) 2014 Andrey Isaev. All rights reserved.
//

#import "ISAEventStack.h"

static NSUInteger const kDefaultMaxSize = 5;

@interface ISAEventStack ()

@property (assign, nonatomic) NSUInteger size;
@property (strong, nonatomic) NSMutableArray *data;

@end

@implementation ISAEventStack

+ (instancetype)stack
{
    ISAEventStack *stack = [ISAEventStack new];
    stack.data = [NSMutableArray array];
    stack.size = kDefaultMaxSize;
    return stack;
}

- (NSArray *)events
{
    return _data;
}

- (void)setMaxSize:(NSUInteger)maxSize
{
    _size = maxSize;
}

- (void)pushEvent:(NSValue *)eventValue;
{
    if (_data.count > _size) {
        [_data removeObjectAtIndex:0];
    }
    [_data addObject:eventValue];
}

- (void)clear
{
    [_data removeAllObjects];
}

@end
