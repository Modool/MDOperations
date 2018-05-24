//
//  MDOperation.h
//  MDOperations
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MDOperation : NSObject
@property (strong, readonly) dispatch_queue_t queue;

@property (assign, readonly, getter=isExecuting) BOOL executing;

@property (assign, readonly, getter=isFinished) BOOL finished;

@property (assign, readonly, getter=isCancelled) BOOL cancelled;

@property (assign, getter=isConcurrent) BOOL concurrent;

@property (copy) void (^block)(MDOperation *operation);

- (void)cancel;
- (void)synchronize;
- (void)asynchronize;

@end
