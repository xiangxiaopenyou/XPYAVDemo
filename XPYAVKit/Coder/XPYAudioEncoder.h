//
//  XPYAudioEncoder.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/15.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol XPYAudioEncoderDelegate <NSObject>

/// 音频编码帧数据回调
- (void)audioEncoderDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 音频编码错误回调
- (void)audioEncoderError:(NSError *)error;

@end

@interface XPYAudioEncoder : NSObject

@property (nonatomic, assign, readonly) NSInteger bitrate;

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

/// 初始化
/// - Parameter bitrate: 码率
- (instancetype)initWithBitrate:(NSInteger)bitrate;

/// 编码
/// - Parameter sampleBuffer: 原始帧数据
- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
