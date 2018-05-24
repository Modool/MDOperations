//
//  MDOperationQueue.h
//  MDOperations
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MDOperation;
@interface MDOperationQueue : NSObject

@property (copy, readonly) NSArray<MDOperation *> *operations;

@property (strong, readonly) dispatch_queue_t queue;

@property (assign, readonly, getter=isExecuting) BOOL executing;

@property (assign, readonly, getter=isCanceled) BOOL canceled;

// Default is NSUIntegerMax
@property (assign) NSUInteger maximumConcurrentCount;

@property (copy) void (^completion)(MDOperationQueue *queue, BOOL success);

+ (instancetype)queue;
+ (instancetype)queueWithOperations:(NSArray<MDOperation *> *)operations;
- (instancetype)initWithOperations:(NSArray<MDOperation *> *)operations;

- (void)addOperation:(MDOperation *)operation;
- (void)addOperations:(NSArray<MDOperation *> *)operations;

- (void)schedule;
- (void)cancel;

- (long)wait:(dispatch_time_t)timeout;
- (long)waitUntilFinished;

@end
