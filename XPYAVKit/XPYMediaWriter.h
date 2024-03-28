//
//  XPYMediaWriter.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/26.
//
//  封装器

#import <Foundation/Foundation.h>
#import <XPYAVKit/XPYAVUtils.h>

@class XPYMediaWriterConfig;

NS_ASSUME_NONNULL_BEGIN

@interface XPYMediaWriter : NSObject

+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

/// 初始化方法
/// @param URL 文件保存路径（如果已经存在文件，会先删除原文件）
/// @param config 编码设置，nil时会使用默认设置
- (instancetype)initWithVideoURL:(NSURL *)URL
                         setting:(nullable XPYMediaWriterConfig *)config;

- (void)start;

- (void)cancel;
/// 封装数据，异步封装
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishWithCompletion:(void (^)(BOOL success, NSError *error))completion;

@end

@interface XPYMediaWriterConfig : NSObject

/// 是否需要音频轨道，默认为YES
@property (nonatomic, assign) XPYMediaType mediaType;

/// 文件格式，默认为AVFileTypeMPEG4
@property (nonatomic, copy) AVFileType fileType;

/// 是否实时数据源，默认为NO
@property (nonatomic, assign) BOOL isRealTimeData;

/// 视频尺寸
@property (nonatomic, assign) CGSize size;

/// 视频图像旋转信息
@property (nonatomic, assign) CGAffineTransform transform;

/// 视频编码格式，默认为AVVideoCodecH264
@property (nonatomic, copy) AVVideoCodecType videoInputFormat;

/// 音频编码格式，默认为kAudioFormatMPEG4AAC
@property (nonatomic, assign) AudioFormatID audioInputFormat;

/// 音频声道数量，默认为2
@property (nonatomic, assign) NSInteger audioChannels;

/// 音频码率，默认为当前硬件码率
@property (nonatomic, assign) double audioRate;

@end

NS_ASSUME_NONNULL_END
