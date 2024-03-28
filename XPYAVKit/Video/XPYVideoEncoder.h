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

/// 尺寸/分辨率
@property (nonatomic, assign) CGSize size;
/// 码率
@property (nonatomic, assign) NSInteger bitrate;
/// 帧率
@property (nonatomic, assign) NSInteger fps;
/// GOP 帧数
@property (nonatomic, assign) NSInteger gopSize;
/// 是否开启B帧
@property (nonatomic, assign) BOOL openBFrame;
/// 编码器类型
@property (nonatomic, assign) CMVideoCodecType codecType;
/// 编码格式(H.264和H.265)
@property (nonatomic, copy) NSString *profileLevel;

@end

@interface XPYVideoEncoder : NSObject

@property (nonatomic, weak) id<XPYVideoEncoderDelegate> delegate;

- (instancetype)initWithConfig:(XPYVideoEncoderConfig *)config;

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp;

@end

NS_ASSUME_NONNULL_END
