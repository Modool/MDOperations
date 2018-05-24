//
//  MDOperationQueue+Private.h
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/17.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import "MDOperationQueue.h"

@interface MDOperation (MDOperationQueue)

- (void)prepareInQueue:(MDOperationQueue *)queue;
- (void)completeInQueue:(MDOperationQueue *)queue;

@end

@interface MDOperationQueue () {
    @protected
    NSMutableArray<MDOperation *> *_mutableOperations;
    NSMutableArray<MDOperation *> *_excutingOperations;
    
    NSRecursiveLock *_lock;
    
    dispatch_queue_t _queue;
    dispatch_group_t _group;
    
    NSUInteger _maximumConcurrentCount;
    
    BOOL _executing;
    BOOL _canceled;
    
    void (^_completion)(MDOperationQueue *queue, BOOL success);
}

- (void)_willBeginSchedule;
- (void)_didEndSchedule;

@end
