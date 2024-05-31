//
//  XPYMediaReader.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/28.
//
//  解封装器

#import <AVFoundation/AVFoundation.h>
#import <XPYAVKit/XPYAVUtils.h>

@class XPYMediaReaderConfig;

NS_ASSUME_NONNULL_BEGIN

@interface XPYMediaReader : NSObject

/// 状态
@property (nonatomic, assign, readonly) AVAssetReaderStatus status;
/// 是否包含音频轨道
@property (nonatomic, assign, readonly) BOOL containsAudioTrack;
/// 是否包含视频轨道
@property (nonatomic, assign, readonly) BOOL contansVideoTrack;
/// 音频是否结束
@property (nonatomic, assign, readonly) BOOL audioFinished;
/// 视频是否结束
@property (nonatomic, assign, readonly) BOOL videoFinished;
/// 视频帧率
@property (nonatomic, assign, readonly) NSInteger frameRate;
/// 视频尺寸
@property (nonatomic, assign, readonly) CGSize videoSize;
/// 时长
@property (nonatomic, assign, readonly) CMTime duration;
/// 编码格式
@property (nonatomic, assign, readonly) CMVideoCodecType codecType;
/// 视频画面方向
@property (nonatomic, assign, readonly) CGAffineTransform transform;


@property (nonatomic, copy) void (^readerError)(NSError *error);

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)URL;

- (instancetype)initWithURL:(NSURL *)URL config:(nullable XPYMediaReaderConfig *)config;

- (instancetype)initWithAsset:(AVAsset *)asset;

- (instancetype)initWithAsset:(AVAsset *)asset config:(nullable XPYMediaReaderConfig *)config;

- (void)startWithCompletion:(void (^)(BOOL success, NSError *error))completion;

- (void)cancel;

- (BOOL)hasAudioSampleBuffer;

- (CMSampleBufferRef)copyNextAudioSampleBuffer CF_RETURNS_RETAINED;

- (BOOL)hasVideoSampleBuffer;

- (CMSampleBufferRef)copyNextVideoSampleBuffer CF_RETURNS_RETAINED;

@end

@interface XPYMediaReaderConfig : NSObject

@property (nonatomic, assign) XPYMediaType mediaType;

/// 输出视频帧格式
/// @note 默认 XPYVideoBufferFormatData
/// XPYVideoBufferFormatData 时输出视频帧 PTS 可能是乱的
@property (nonatomic, assign) XPYVideoBufferFormat videoBufferFormat;

@end

NS_ASSUME_NONNULL_END
