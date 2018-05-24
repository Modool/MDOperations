//
//  MDOperationQueue.m
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import "MDOperationQueue.h"
#import "MDOperationQueue+Private.h"
#import "MDOperation+Private.h"

NSString * const MDOperationQueueDomainPrefix = @"com.markejave.modool.operation.queue";

@implementation MDOperation (MDOperationQueue)

- (void)prepareInQueue:(MDOperationQueue *)queue;{}
- (void)completeInQueue:(MDOperationQueue *)queue;{}

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
        _lock = [[NSRecursiveLock alloc] init];
        _mutableOperations = [NSMutableArray arrayWithArray:operations ?: @[]];
        _excutingOperations = [NSMutableArray new];
        _maximumConcurrentCount = NSUIntegerMax;
        
        NSString *queueName = [MDOperationQueueDomainPrefix stringByAppendingFormat:@"%@#Concurrent#%lu", NSStringFromClass([self class]), (unsigned long)self];
        _queue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
        _group = dispatch_group_create();
    }
    return self;
}

#pragma mark - accessor

- (NSArray<MDOperation *> *)operations{
    [_lock lock];
    NSArray<MDOperation *> *operations = [_mutableOperations copy];
    [_lock unlock];
    
    return operations;
}

- (NSUInteger)maximumConcurrentCount{
    [_lock lock];
    NSUInteger maximumConcurrentCount = _maximumConcurrentCount;
    [_lock unlock];
    
    return maximumConcurrentCount;
}

- (void)setMaximumConcurrentCount:(NSUInteger)maximumConcurrentCount{
    [_lock lock];
    _maximumConcurrentCount = maximumConcurrentCount;
    [_lock unlock];
}

- (BOOL)isExecuting{
    [_lock lock];
    BOOL executing = _executing;
    [_lock unlock];
    
    return executing;
}

- (BOOL)isCanceled{
    [_lock lock];
    BOOL canceled = self->_canceled;
    [_lock unlock];
    
    return canceled;
}

- (void)setCompletion:(void (^)(MDOperationQueue *, BOOL))completion{
    [_lock lock];
    _completion = [completion copy];
    [_lock unlock];
}

- (void (^)(MDOperationQueue *, BOOL))completion{
    [_lock lock];
    void (^completion)(MDOperationQueue *, BOOL) = [_completion copy];
    [_lock unlock];
    return completion;
}

- (dispatch_queue_t)queue{
    [_lock lock];
    dispatch_queue_t queue = _queue;
    [_lock unlock];
    return queue;
}

#pragma mark - public

- (void)addOperation:(MDOperation *)operation;{
    if (!operation) return;
    
    [self addOperations:@[operation]];
}

- (void)addOperations:(NSArray<MDOperation *> *)operations;{
    if (![operations count]) return;
    [_lock lock];
    [self _addOperations:operations];
    [_lock unlock];
}

- (void)schedule;{
    NSParameterAssert(![self isExecuting]);
    
    [_lock lock];
    [self _schedule];
    [_lock unlock];
}

- (void)cancel;{
    [_lock lock];
    [self _cancel];
    [_lock unlock];
}

- (long)wait:(dispatch_time_t)timeout;{
    if (isless(timeout, 0.0)) {
        timeout = DISPATCH_TIME_FOREVER;
    } else {
        timeout = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
    }
    
    return [self _wait:timeout];
}

- (long)waitUntilFinished;{
    return [self _wait:DISPATCH_TIME_FOREVER];
}

#pragma mark - private

- (void)_cancel{
    dispatch_suspend(_queue);
    
    for (MDOperation *operation in _mutableOperations) {
        [operation cancel];
    }
    
    for (MDOperation *operation in _excutingOperations) {
        [operation cancel];
    }
    
    [_mutableOperations removeAllObjects];
    
    _canceled = YES;
    
    dispatch_resume(_queue);
}

- (void)_addOperations:(NSArray<MDOperation *> *)operations;{
    dispatch_suspend(_queue);
    
    [_mutableOperations addObjectsFromArray:operations];
    
    if (_executing) [self _schedule];
    
    dispatch_resume(_queue);
}

- (void)_schedule{
    NSArray<MDOperation *> *operations = _mutableOperations.copy;
    if(![operations count]) return;
    
    NSUInteger count = MIN(_maximumConcurrentCount - [_excutingOperations count], [operations count]);
    if (!count) return;
    
    operations = [operations subarrayWithRange:NSMakeRange(0, count)];
    if(![operations count]) return;
    
    [_mutableOperations removeObjectsInArray:operations];
    
    _canceled = NO;
    [self _willBeginSchedule];
    [self _scheduleOperations:operations];
}

- (void)_scheduleOperations:(NSArray<MDOperation *> *)operations{
    if(![operations count]) return;
    
    [_excutingOperations addObjectsFromArray:operations];
    
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
    if(!operation) return;
    
    [self _runOperations:@[operation]];
}

- (void)_runOperations:(NSArray<MDOperation *> *)operations{
    if(![operations count]) return;
    _executing = YES;
    
    dispatch_group_async(_group, _queue, ^{
        for (MDOperation *operation in operations) {
            [self _runMainWithOpeartion:operation];
            [self _completeWithOperation:operation];
        }
    });
}

- (void)_runMainWithOpeartion:(MDOperation *)operation{
    dispatch_sync([operation queue], ^{
        [operation prepareInQueue:self];
        [operation main];
        [operation completeInQueue:self];
    });
}

- (void)_completeWithOperation:(MDOperation *)operation{
    [_lock lock];
    [_excutingOperations removeObject:operation];
    BOOL continued = [_mutableOperations count] > 0;
    if (!continued) {
        [self _completeForCanceled:[operation isCancelled]];
    }
    [_lock unlock];
    
    if (continued) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self->_lock lock];
            [self _schedule];
            [self->_lock unlock];
        });
    }
}

- (void)_completeForCanceled:(BOOL)canceled{
    _executing = NO;
    
    if (_completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_completion(self, !canceled && !self->_canceled);
        });
    }
    [self _didEndSchedule];
}

- (long)_wait:(dispatch_time_t)timeout;{
    [_lock lock];
    dispatch_group_t group = _group;
    [_lock unlock];
    
    return dispatch_group_wait(group, timeout);
}

- (void)_willBeginSchedule;{}

- (void)_didEndSchedule;{}

@end
