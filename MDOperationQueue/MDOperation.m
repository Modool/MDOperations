//
//  MDOperation.m
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import "MDOperation.h"
#import "MDOperation+Private.h"

NSString * const MDOperationDomainPrefix = @"com.modool.operation#";

@implementation MDOperation

+ (instancetype)operationWithConcurrent:(BOOL)concurrent block:(void (^)(MDOperation *operation))block;{
    return [[self alloc] initWithConcurrent:concurrent block:block];
}

- (instancetype)initWithConcurrent:(BOOL)concurrent block:(void (^)(MDOperation *operation))block;{
    if (self = [self init]) {
        self.concurrent = concurrent;
        self.block = block;
    }
    return self;
}

- (instancetype)init{
    if (self = [super init]) {
        NSString *queueName = [NSString stringWithFormat:@"%@%lu", MDOperationDomainPrefix, (unsigned long)self];
        self.queueTag = &_queueTag;
        self.queue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_queue_set_specific([self queue], _queueTag, _queueTag, NULL);
    }
    return self;
}

#pragma mark - accessor

- (BOOL)isConcurrent{
    __block BOOL concurrent = NO;
    [self _sync:^{
        concurrent = self->_concurrent;
    }];
    return concurrent;
}

#pragma mark - public

- (void)synchronize;{
    if (_runInQueue) return;
    
    [self _synchronize];
}

- (void)asynchronize;{
    [self asynchronizeWithCompletion:nil];
}

- (void)asynchronizeWithCompletion:(void (^)(MDOperation *operation))completion;{
    if (_runInQueue) return;
    
    [self _asynchronizeWithCompletion:completion];
}

- (void)cancel;{
    _cancelled = YES;
}

#pragma mark - private

- (void)_async:(dispatch_block_t)block;{
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_async(_queue, block);
    }
}

- (void)_sync:(dispatch_block_t)block;{
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_sync(_queue, block);
    }
}

- (void)_synchronize;{
    [self _sync:^{
        [self main];
    }];
}

- (void)_asynchronizeWithCompletion:(void (^)(MDOperation *operation))completion;{
    [self _async:^{
        [self main];
        
        if (completion) { dispatch_async(dispatch_get_main_queue(), ^{
            completion(self);
        });};
    }];
}

#pragma mark - protected

- (void)main{
    if (_cancelled) return;
    if (_finished) return;
    
    _executing = YES;
    
    if ([self block]) self.block(self);
    [self run];
    
    _executing = NO;
    _finished = YES;
}

- (void)run;{
    
}

@end
