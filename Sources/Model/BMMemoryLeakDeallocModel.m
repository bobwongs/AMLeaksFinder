//
//  BMMemoryLeakDeallocModel.m
//  BMeaksFinder
//
//  Created by mac on 2020/5/18.
//  Copyright © 2020 liangdahong. All rights reserved.
//

#import "BMMemoryLeakDeallocModel.h"
#import "UIViewController+BMMemoryLeakUI.h"
#import "BMMemoryLeakModel.h"
#import "UIViewController+AMLeaksFinderTools.h"

@implementation BMMemoryLeakDeallocModel

- (void)dealloc {
    [UIViewController.memoryLeakModelArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(BMMemoryLeakModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.memoryLeakDeallocModel == self) {
            [UIViewController.memoryLeakModelArray removeObjectAtIndex:idx];
            *stop = YES;
         }
    }];
    [UIViewController udpateUI];
}

@end
