//
//  XPYFrameProducer.h
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XPYFrameProducer : NSObject

/// 需要排序情况：数量到达最大容量并排序后进入 ready 为 YES
/// 不需要排序情况：
@property (nonatomic, assign, readonly, getter=isReader) BOOL ready;
/// 是否需要排序
@property (nonatomic, assign) BOOL needsSorting;
/// 最大缓存帧容量，默认为 8
@property (nonatomic, assign) NSInteger capacity;

- (instancetype)initWithMediaURL:(NSURL *)mediaURL;

/// 开始
- (void)startWithCompletion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
