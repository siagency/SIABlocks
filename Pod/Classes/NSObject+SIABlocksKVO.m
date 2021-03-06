//
//  NSObject+SIABlocksKVO.m
//  SIATools
//
//  Created by KUROSAKI Ryota on 2013/01/31.
//  Copyright (c) 2013-2014 SI Agency Inc. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This code needs compiler option -fobjc_arc
#endif

#import "NSObject+SIABlocksKVO.h"
#import <objc/runtime.h>

#define SIAObserverActionListKey "SIAObserverActionListKey"

@interface SIAObserverAction : NSObject

@property (nonatomic, copy, readonly) NSString *keyPath;
@property (nonatomic, assign, readonly) NSKeyValueObservingOptions options;
@property (nonatomic, weak, readonly) NSOperationQueue *queue;
@property (nonatomic, copy, readonly) void (^block)(NSDictionary *change);

@end

@implementation SIAObserverAction

- (id)initWithKeyPath:(NSString *)keyPath
              options:(NSKeyValueObservingOptions)options
                queue:(NSOperationQueue *)queue
           usingBlock:(void (^)(NSDictionary *change))block
{
    self = [super init];
    if (self) {
        _keyPath = keyPath;
        _options = options;
        _queue = queue;
        _block = block;
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (self.queue && self.queue != [NSOperationQueue currentQueue]) {
        [self.queue addOperationWithBlock:^{
            _block(change);
        }];
    }
    else {
        _block(change);
    }
}

@end

@implementation NSObject (SIABlocksKVO)

- (NSMutableArray *)sia_observerActions
{
    NSMutableArray *actions = nil;
    @synchronized(self) {
        actions = objc_getAssociatedObject(self, SIAObserverActionListKey);
        if (actions == nil) {
            actions = @[].mutableCopy;
            objc_setAssociatedObject(self, SIAObserverActionListKey, actions, OBJC_ASSOCIATION_RETAIN);
        }
    }
    return actions;
}

- (SIAObserverAction *)sia_addActionForKeyPath:(NSString *)keyPath
                                       options:(NSKeyValueObservingOptions)options
                                         queue:(NSOperationQueue *)queue
                                    usingBlock:(void (^)(NSDictionary *change))block
{
    SIAObserverAction *action = [[SIAObserverAction alloc] initWithKeyPath:keyPath
                                                                   options:options
                                                                     queue:queue
                                                                usingBlock:block];
    [self addObserver:action forKeyPath:keyPath options:options context:nil];
    [[self sia_observerActions] addObject:action];
    return action;
}

- (void)sia_removeObserverAction:(SIAObserverAction *)action
{
    [self removeObserver:action forKeyPath:action.keyPath context:nil];
    [[self sia_observerActions] removeObject:action];
}

- (void)sia_removeAllObserverAction
{
    for (SIAObserverAction *action in [self sia_observerActions]) {
        [self sia_removeObserverAction:action];
    }
}

@end