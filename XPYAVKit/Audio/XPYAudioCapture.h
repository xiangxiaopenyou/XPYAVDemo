//
//  XPYAudioCapture.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//
//  音频采集类

#import <AVFoundation/AVFoundation.h>

@class XPYAudioConfig;

NS_ASSUME_NONNULL_BEGIN

@protocol XPYAudioCaptureDelegate <NSObject>

/// 音频采集帧回调
- (void)audioCaptureDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 音频采集错误回调
- (void)audioCaptureError:(NSError *)error;

@end

@interface XPYAudioCapture : NSObject

@property (nonatomic, strong, readonly) XPYAudioConfig *config;

@property (nonatomic, copy) id<XPYAudioCaptureDelegate> delegate;

- (instancetype)initWithConfig:(XPYAudioConfig *)config;

- (void)startCapturing;

- (void)stopCapturing;

@end

NS_ASSUME_NONNULL_END
