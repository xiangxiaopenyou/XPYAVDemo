//
//  XPYVideoCapture.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/20.
//

#import <AVFoundation/AVFoundation.h>

@class XPYVideoCaptureConfig;

NS_ASSUME_NONNULL_BEGIN

@protocol XPYVideoCaptureDelegate <NSObject>

/// 视频采集帧回调
- (void)videoCaptureDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 视频采集错误回调
- (void)videoCaptureError:(NSError *)error;

@end

@interface XPYVideoCapture : NSObject

@property (nonatomic, weak) id<XPYVideoCaptureDelegate> delegate;

- (instancetype)initWithConfig:(XPYVideoCaptureConfig *)config;

- (void)startCapturing;

- (void)stopCapturing;

/// 切换前后置摄像头
- (BOOL)switchDevicePosition:(AVCaptureDevicePosition)position;

@end

@interface XPYVideoCaptureConfig : NSObject
/// 帧率，默认 30
@property (nonatomic, assign) NSInteger fps;
/// 分辨率， 默认 AVCaptureSessionPreset1280x720
@property (nonatomic, copy) AVCaptureSessionPreset preset;
/// 前/后置摄像头，默认 AVCaptureDevicePositionFront
@property (nonatomic, assign) AVCaptureDevicePosition position;
/// 视频画面方向，默认 AVCaptureVideoOrientationPortrait
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
/// 采集内存格式，默认 kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
@property (nonatomic, assign) OSType formatType;
/// 是否镜像，默认 YES（前置镜像 后置非镜像）
@property (nonatomic, assign) BOOL mirrored;

@end

NS_ASSUME_NONNULL_END
