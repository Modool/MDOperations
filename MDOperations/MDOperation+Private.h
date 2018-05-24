//
//  MDOperation+Private.h
//  MDOperations
//
//  Created by xulinfeng on 2018/5/11.
//  Copyright © 2018年 markejave. All rights reserved.
//

#import "MDOperation.h"

@interface MDOperation (){
    void *_queueTag;
    
    NSString *_name;
    dispatch_queue_t _queue;
    
    BOOL _concurrent;
    BOOL _executing;
    BOOL _finished;
    BOOL _cancelled;
    void (^_block)(MDOperation *operation);
}

- (void)_async:(dispatch_block_t)block;
- (void)_sync:(dispatch_block_t)block;

- (void)main;
- (void)run;

@end
