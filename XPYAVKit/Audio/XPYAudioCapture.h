//
//  XPYAudioCapture.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//
//  音频采集类

#import <AVFoundation/AVFoundation.h>

@class XPYAudioCaptureConfig;

NS_ASSUME_NONNULL_BEGIN

@protocol XPYAudioCaptureDelegate <NSObject>

/// 音频采集帧回调
- (void)audioCaptureDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 音频采集错误回调
- (void)audioCaptureError:(NSError *)error;

@end

@interface XPYAudioCapture : NSObject

@property (nonatomic, strong, readonly) XPYAudioCaptureConfig *config;

@property (nonatomic, weak) id<XPYAudioCaptureDelegate> delegate;

- (instancetype)initWithConfig:(XPYAudioCaptureConfig *)config;

- (void)startCapturing;

- (void)stopCapturing;

@end

@interface XPYAudioCaptureConfig : NSObject

/// 声道数，默认为 2
@property (nonatomic, assign) NSUInteger channelsNumber;
/// 采样率，默认为 44100
@property (nonatomic, assign) NSUInteger samplingRate;
/// 量化位深，默认为 16
@property (nonatomic, assign) NSUInteger bitDepth;

@end

NS_ASSUME_NONNULL_END
