//
//  XPYFrameProducer.h
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/28.
//

#import <Foundation/Foundation.h>
#import <XPYAVKit/XPYAVKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XPYFrameProducer : NSObject

@property (nonatomic, strong, readonly) XPYMediaReader *reader;

/// 是否需要排序
@property (nonatomic, assign) BOOL needsSorting;
/// 最大缓存帧容量，默认为 8
@property (nonatomic, assign) NSInteger capacity;

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;


- (instancetype)initWithMediaURL:(NSURL *)mediaURL;

/// 开始
- (void)startWithCompletion:(void (^)(BOOL success))completion;

/// 获取视频帧
/// @note 使用完需要手动 release
- (CVPixelBufferRef)getNextPixelBuffer;

@end

NS_ASSUME_NONNULL_END
