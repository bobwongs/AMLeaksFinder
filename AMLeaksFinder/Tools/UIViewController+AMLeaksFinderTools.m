//    MIT License
//
//    Copyright (c) 2020 梁大红
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

#import "UIViewController+AMLeaksFinderTools.h"
#import <objc/runtime.h>
#import "UIViewController+AMLeaksFinderUI.h"
#import "AMMemoryLeakModel.h"

void amleaks_finder_swizzleInstanceMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    if (class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@implementation UIViewController (AMLeaksFinderTools)

+ (NSMutableArray<AMMemoryLeakModel *> *)memoryLeakModelArray {
    static NSMutableArray <AMMemoryLeakModel *> *arr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        arr = @[].mutableCopy;
    });
    return arr;
}

/// 返回 【自己】+【自己所有的子子孙孙控制器】组成的数组
- (NSArray<UIViewController *> *)amleaks_finder_selfAndAllChildController {
    NSMutableArray *arr = @[self].mutableCopy;
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [arr addObjectsFromArray:obj.amleaks_finder_selfAndAllChildController.copy];
    }];
    return arr.copy;
}

- (void)amleaks_finder_shouldDealloc {
    [self.amleaks_finder_selfAndAllChildController enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [UIViewController.memoryLeakModelArray enumerateObjectsUsingBlock:^(AMMemoryLeakModel * _Nonnull obj1, NSUInteger idx1, BOOL * _Nonnull stop1) {
            if (obj1.memoryLeakDeallocModel.controller == obj) {
                obj1.memoryLeakDeallocModel.shouldDealloc = YES;
            }
        }];
    }];

    // 延时刷新 UI
    // 因为控制器在 pop diss 的时候需要时间才回收
    // 但是要保证数据的准确性，只是延迟刷新 UI
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // update ui
        [UIViewController udpateUI];
    });
}

+ (void)amleaks_finder_shouldAllDeallocBesidesController:(UIViewController *)controller window:(UIWindow *)window {
    NSMutableArray <UIViewController *> *arr = controller.amleaks_finder_selfAndAllChildController.mutableCopy;
    [UIViewController.memoryLeakModelArray enumerateObjectsUsingBlock:^(AMMemoryLeakModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.memoryLeakDeallocModel.controller.view.window == window) {
            __block BOOL flag = NO;
            [arr enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj1, NSUInteger idx1, BOOL * _Nonnull stop1) {
                if (obj1 == obj.memoryLeakDeallocModel.controller) {
                    flag = YES;
                    *stop = YES;
                    [arr removeObjectAtIndex:idx1];
                }
            }];
            if (!flag) {
                [obj.memoryLeakDeallocModel.controller amleaks_finder_shouldDealloc];
            }
        }
    }];
}

- (void)amleaks_finder_normal {
    [self.amleaks_finder_selfAndAllChildController enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [UIViewController.memoryLeakModelArray enumerateObjectsUsingBlock:^(AMMemoryLeakModel * _Nonnull obj1, NSUInteger idx1, BOOL * _Nonnull stop1) {
            if (obj1.memoryLeakDeallocModel.controller == obj
                && obj1.memoryLeakDeallocModel.shouldDealloc) {
                // 如果控制器已经设置为将要释放
                // 就改为正常
                obj1.memoryLeakDeallocModel.shouldDealloc = NO;
            }
        }];
    }];
    // update ui
    [UIViewController udpateUI];
}

+ (__kindof UIViewController *)amleaks_finder_TopViewController {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    UIViewController *topvc = window.rootViewController;
    while (topvc.presentedViewController) {
        topvc = topvc.presentedViewController;
    }
    return topvc;
}

+ (__kindof UIWindow *)amleaks_finder_TopWindow {
    __block UIWindow *window = nil;
    [UIApplication.sharedApplication.windows enumerateObjectsWithOptions:(NSEnumerationReverse) usingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!obj.hidden
            && obj.alpha > 0.1
            && obj.screen == UIScreen.mainScreen
            && obj.windowLevel >= UIWindowLevelNormal
            && obj.userInteractionEnabled
            ) {
            window = obj;
            *stop = YES;
        }
    }];
    return window;
}

@end
