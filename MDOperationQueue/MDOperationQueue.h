//
//  MDOperationQueue.h
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for MDOperationQueue.
FOUNDATION_EXPORT double MDOperationQueueVersionNumber;

//! Project version string for MDOperationQueue.
FOUNDATION_EXPORT const unsigned char MDOperationQueueVersionString[];

#import "MDOperation.h"

@interface MDOperationQueue : NSObject

@property (nonatomic, assign, readonly, getter=isExecuting) BOOL executing;

@property (nonatomic, assign, readonly, getter=isCanceled) BOOL canceled;

@property (nonatomic, copy, readonly) NSArray<MDOperation *> *operations;

// Default is NSUIntegerMax
@property (nonatomic, assign) NSUInteger maximumConcurrentCount;

@property (nonatomic, copy) void (^completion)(MDOperationQueue *queue, BOOL success);

+ (instancetype)queue;
+ (instancetype)queueWithOperations:(NSArray<MDOperation *> *)operations;

- (instancetype)initWithOperations:(NSArray<MDOperation *> *)operations;

- (void)addOperation:(MDOperation *)operation;
- (void)addOperations:(NSArray<MDOperation *> *)operations;

- (void)schedule;
- (void)cancel;

- (long)wait:(NSTimeInterval)timeout;
- (long)waitUntilFinished;

@end
