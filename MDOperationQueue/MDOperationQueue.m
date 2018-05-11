//
//  MDOperationQueue.m
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import "MDOperationQueue.h"
#import "MDOperation+Private.h"

NSString * const MDOperationQueueDomainPrefix = @"com.modool.operation.queue#";

@interface MDOperationQueue () {
    NSUInteger _maximumConcurrentCount;
    BOOL _executing;
    BOOL _canceled;
}

@property (nonatomic, strong) NSMutableArray<MDOperation *> *mutableOperations;
@property (nonatomic, strong) NSMutableArray<MDOperation *> *excutingOperations;

@property (nonatomic, strong) dispatch_queue_t operationQueue;
@property (nonatomic, strong) dispatch_group_t group;

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) void *queueTag;

@end

@implementation MDOperationQueue
@dynamic queue;

+ (instancetype)queue;{
    return [self queueWithOperations:nil];
}

+ (instancetype)queueWithOperations:(NSArray<MDOperation *> *)operations;{
    return [[self alloc] initWithOperations:operations];
}

- (instancetype)initWithOperations:(NSArray<MDOperation *> *)operations;{
    if (self = [super init]) {
        self.mutableOperations = [NSMutableArray arrayWithArray:operations ?: @[]];
        self.excutingOperations = [NSMutableArray new];
        self.maximumConcurrentCount = NSUIntegerMax;
        
        NSString *operationQueueName = [MDOperationQueueDomainPrefix stringByAppendingFormat:@"%@#Concurrent#%lu", NSStringFromClass([self class]), (unsigned long)self];
        self.operationQueue = dispatch_queue_create([operationQueueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
        
        NSString *queueName = [NSString stringWithFormat:@"%@%lu", MDOperationQueueDomainPrefix, (unsigned long)self];
        self.queueTag = &_queueTag;
        self.queue = dispatch_queue_create([queueName UTF8String], NULL);
        dispatch_queue_set_specific([self queue], _queueTag, _queueTag, NULL);
        
        self.group = dispatch_group_create();
    }
    return self;
}

#pragma mark - accessor

- (NSArray<MDOperation *> *)operations{
    __block NSArray<MDOperation *> *operations = nil;
    dispatch_block_t block = ^{
        operations = [[self mutableOperations] copy];
    };
    
    [self _sync:block];
    
    return operations;
}

- (NSUInteger)maximumConcurrentCount{
    __block NSUInteger maximumConcurrentCount = 0;
    dispatch_block_t block = ^{
        maximumConcurrentCount = self->_maximumConcurrentCount;
    };
    
    [self _sync:block];
    
    return maximumConcurrentCount;
}

- (void)setMaximumConcurrentCount:(NSUInteger)maximumConcurrentCount{
    dispatch_block_t block = ^{
        self->_maximumConcurrentCount = maximumConcurrentCount;
    };
    
    [self _sync:block];
}

- (BOOL)isExecuting{
    __block BOOL executing = NO;
    [self _sync:^{
        executing = self->_executing;
    }];
    return executing;
}

- (BOOL)isCanceled{
    __block BOOL canceled = NO;
    [self _sync:^{
        canceled = self->_canceled;
    }];
    return canceled;
}

#pragma mark - public

- (void)addOperation:(MDOperation *)operation;{
    NSParameterAssert(operation);
    
    [self addOperations:@[operation]];
}

- (void)addOperations:(NSArray<MDOperation *> *)operations;{
    NSParameterAssert(operations);
    if (![operations count]) return;
    
    dispatch_block_t block = ^{
        [self _addOperations:operations];
    };
    
    [self _sync:block];
}

- (void)schedule;{
    NSParameterAssert(![self isExecuting]);
    
    dispatch_block_t block = ^{
        [self _schedule];
    };
    
    [self _sync:block];
}

- (void)cancel;{
    dispatch_block_t block = ^{
        [self _cancel];
    };
    
    [self _sync:block];
}

- (long)wait:(NSTimeInterval)timeout;{
    NSAssert(![[NSThread currentThread] isMainThread], @"Can't in mainthread");
    if (!self.executing) return 0;
    
    dispatch_time_t time = 0;
    if (isless(timeout, 0.0)) {
        time = DISPATCH_TIME_FOREVER;
    } else {
        time = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
    }
    
    __block dispatch_group_t group;
    [self _sync:^{
        group = self->_group;
    }];
    return dispatch_group_wait(group, time);;
}

- (long)waitUntilFinished;{
    return [self wait:-1];
}

#pragma mark - private

- (void)_async:(dispatch_block_t)block;{
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_async([self queue], block);
    }
}

- (void)_sync:(dispatch_block_t)block;{
    if (dispatch_get_specific(_queueTag)) {
        block();
    } else {
        dispatch_sync([self queue], block);
    }
}

- (void)_cancel{
    dispatch_suspend([self operationQueue]);
    
    for (MDOperation *operation in [self mutableOperations]) {
        [operation cancel];
    }
    
    for (MDOperation *operation in [self excutingOperations]) {
        [operation cancel];
    }
    
    [[self mutableOperations] removeAllObjects];
    
    _canceled = YES;
    
    dispatch_resume([self operationQueue]);
}

- (void)_addOperations:(NSArray<MDOperation *> *)operations;{
    dispatch_suspend([self operationQueue]);
    
    [operations setValue:@YES forKey:@"runInQueue"];
    [[self mutableOperations] addObjectsFromArray:operations];
    
    if (_executing) [self _schedule];
    
    dispatch_resume([self operationQueue]);
}

- (void)_schedule{
    NSArray<MDOperation *> *operations = [self operations];
    if (![operations count]) return;
    
    NSUInteger count = MIN([self maximumConcurrentCount] - [[self excutingOperations] count], [operations count]);
    if (!count) return;
    
    operations = [operations subarrayWithRange:NSMakeRange(0, count)];
    if (![operations count]) return;
    
    [[self mutableOperations] removeObjectsInArray:operations];
    
    _canceled = NO;
    
    [self _scheduleOperations:operations];
}

- (void)_scheduleOperations:(NSArray<MDOperation *> *)operations{
    [[self excutingOperations] addObjectsFromArray:operations];
    
    NSMutableArray<MDOperation *> *synchronousOperations = [NSMutableArray<MDOperation *> new];
    for (MDOperation *operation in operations) {
        if ([operation isFinished] || [operation isCancelled] || [operation isExecuting]) continue;
        
        if ([operation isConcurrent]) {
            [self _runOperation:operation];
        } else {
            [synchronousOperations addObject:operation];
        }
    }
    
    if ([synchronousOperations count]) {
        [self _runOperations:synchronousOperations];
    }
}

- (void)_runOperation:(MDOperation *)operation{
    NSParameterAssert(operation);
    
    [self _runOperations:@[operation]];
}

- (void)_runOperations:(NSArray<MDOperation *> *)operations{
    _executing = YES;
    
    dispatch_group_async([self group], [self operationQueue], ^{
        for (MDOperation *operation in operations) {
            [self _runMainWithOpeartion:operation];
        }
    });
}

- (void)_runMainWithOpeartion:(MDOperation *)operation{
    [operation _synchronize];
    
    dispatch_block_t block = ^{
        [self _completeWithOperation:operation];
    };
    
    [self _sync:block];
}

- (void)_completeWithOperation:(MDOperation *)operation{
    [[self excutingOperations] removeObject:operation];
    
    if ([[self mutableOperations] count]) {
        [self _schedule];
    } else {
        [self _completeForCanceled:[operation isCancelled]];
    }
}

- (void)_completeForCanceled:(BOOL)canceled{
    _executing = NO;
    
    if (!_completion) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_completion(self, !canceled && !self->_canceled);
    });
}

@end
