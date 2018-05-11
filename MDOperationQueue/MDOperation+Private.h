//
//  MDOperation+Private.h
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import "MDOperation.h"

@interface MDOperation ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) void *queueTag;

@property (nonatomic, assign, getter=isRunningInQueue) BOOL runInQueue;
@property (nonatomic, assign, getter=isConcurrent) BOOL concurrent;

@property (nonatomic, copy) void (^block)(MDOperation *operation);

@end

@interface MDOperation (BBLinkPrivate)

- (void)_synchronize;
- (void)_asynchronizeWithCompletion:(void (^)(MDOperation *operation))completion;

- (void)main;
- (void)run;

@end
