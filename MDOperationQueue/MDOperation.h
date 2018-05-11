//
//  MDOperation.h
//  MDOperationQueue
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MDOperation : NSObject

@property (nonatomic, assign, readonly, getter=isConcurrent) BOOL concurrent;

@property (nonatomic, assign, readonly, getter=isExecuting) BOOL executing;

@property (nonatomic, assign, readonly, getter=isFinished) BOOL finished;

@property (nonatomic, assign, readonly, getter=isCancelled) BOOL cancelled;

+ (instancetype)operationWithConcurrent:(BOOL)concurrent block:(void (^)(MDOperation *operation))block;
- (instancetype)initWithConcurrent:(BOOL)concurrent block:(void (^)(MDOperation *operation))block;

- (void)synchronize;
- (void)asynchronize;
- (void)asynchronizeWithCompletion:(void (^)(MDOperation *operation))completion;
- (void)cancel;

@end
