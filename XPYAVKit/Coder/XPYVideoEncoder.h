//
//  XPYVideoEncoder.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/20.
//

#import <AVFoundation/AVFoundation.h>


NS_ASSUME_NONNULL_BEGIN

@protocol XPYVideoEncoderDelegate <NSObject>

/// 视频编码帧数据回调
- (void)videoEncoderDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// 视频编码错误回调
- (void)videoEncoderError:(NSError *)error;

@end

@interface XPYVideoEncoderConfig : NSObject

/// 尺寸/分辨率，默认 720 x 1280
@property (nonatomic, assign) CGSize size;
/// 帧率，默认30
@property (nonatomic, assign) NSInteger fps;
/// 码率，默认 720 x 1280 x 帧率 * 0.15
@property (nonatomic, assign) NSInteger bitrate;
/// GOP 帧数，默认 fps * 5
@property (nonatomic, assign) NSInteger gopSize;
/// 是否开启B帧
@property (nonatomic, assign) BOOL openBFrame;
/// 编码器类型
@property (nonatomic, assign) CMVideoCodecType codecType;
/// 编码格式(H.264和H.265)，默认 kCMVideoCodecType_HEVC，若不支持则使用 kCMVideoCodecType_H264
@property (nonatomic, copy) NSString *profileLevel;

@end

@interface XPYVideoEncoder : NSObject

@property (nonatomic, weak) id<XPYVideoEncoderDelegate> delegate;

- (instancetype)initWithConfig:(XPYVideoEncoderConfig *)config;

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp;

/// 刷新编码器，内部会销毁旧的创建新的
- (void)refresh;
/// 清空编码缓冲区
- (void)clear;

@end

NS_ASSUME_NONNULL_END
