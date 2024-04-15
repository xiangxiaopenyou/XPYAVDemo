//
//  XPYVideoEncoder.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/20.
//

#import "XPYVideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

static const NSInteger kXPYMaxRetrySessionCount = 5;

static const NSInteger kXPYMaxEncodeFaildCount = 10;

@interface XPYVideoEncoder ()

@property (nonatomic, strong) XPYVideoEncoderConfig *config;
@property (nonatomic, assign) VTCompressionSessionRef compressionSession;

@property (nonatomic, strong) dispatch_queue_t encoderQueue;
@property (nonatomic, strong) dispatch_semaphore_t encoderSemaphore;
/// 刷新编码器的次数
@property (nonatomic, assign) NSInteger retrySessionCount;
/// 编码失败次数
@property (nonatomic, assign) NSInteger encodeFaildCount;


@end

@implementation XPYVideoEncoder

- (instancetype)init {
    return [self initWithConfig:[XPYVideoEncoderConfig new]];
}

- (instancetype)initWithConfig:(XPYVideoEncoderConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        _encoderQueue = dispatch_queue_create("com.xpy.videoEncodeQueue", DISPATCH_QUEUE_SERIAL);
        _encoderSemaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp {
    if (pixelBuffer == NULL || self.retrySessionCount > kXPYMaxRetrySessionCount || self.encodeFaildCount > kXPYMaxEncodeFaildCount) {
        return;
    }
    CVPixelBufferRetain(pixelBuffer);
    // 异步编码
    dispatch_async(self.encoderQueue, ^{
        dispatch_semaphore_wait(self.encoderSemaphore, DISPATCH_TIME_FOREVER);
        OSStatus status = noErr;
        if (!self->_compressionSession) {
            [self destoryCompressionSession];
        }
        status = [self createCompressionSession];
        if (status != noErr) {
            // 创建编码器失败
            [self destoryCompressionSession];
            self.retrySessionCount += 1;
            CVPixelBufferRelease(pixelBuffer);
            dispatch_semaphore_signal(self.encoderSemaphore);
            if (self.retrySessionCount > kXPYMaxRetrySessionCount) {
                // 重试次数超过限制时需要报错
                if (self.delegate && [self.delegate respondsToSelector:@selector(videoEncoderError:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate videoEncoderError:[NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil]];
                    });
                }
            }
            return;
        }
        
        self.retrySessionCount = 0;
        
        // 开始编码
        VTEncodeInfoFlags flags;
        status = VTCompressionSessionEncodeFrame(self.compressionSession, pixelBuffer, timeStamp, CMTimeMake(1, (int32_t)self.config.fps), NULL, NULL, &flags);
        if (status == kVTInvalidSessionErr) {
            // 编码失败，重新创建编码器
            [self destoryCompressionSession];
            status = [self createCompressionSession];
            if (status == noErr) {
                self.retrySessionCount = 0;
                status = VTCompressionSessionEncodeFrame(self.compressionSession, pixelBuffer, timeStamp, CMTimeMake(1, (int32_t)self.config.fps), NULL, NULL, &flags);
            } else {
                self.retrySessionCount += 1;
                [self destoryCompressionSession];
            }
        }

        if (status != noErr) {
            self.encodeFaildCount += 1;
            CVPixelBufferRelease(pixelBuffer);
            dispatch_semaphore_signal(self.encoderSemaphore);
            if (self.encodeFaildCount > kXPYMaxEncodeFaildCount) {
                // 编码失败次数超过限制时需要报错
                if (self.delegate && [self.delegate respondsToSelector:@selector(videoEncoderError:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate videoEncoderError:[NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil]];
                    });
                }
            }
            return;
        }
        self.encodeFaildCount = 0;
    });
}

- (void)refresh {
    dispatch_async(self.encoderQueue, ^{
        dispatch_semaphore_wait(self.encoderSemaphore, DISPATCH_TIME_FOREVER);
        [self destoryCompressionSession];
        [self createCompressionSession];
        dispatch_semaphore_signal(self.encoderSemaphore);
    });
}

- (void)clear {
    if (_compressionSession) {
        VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeInvalid);
    }
}

- (OSStatus)createCompressionSession {
    // 创建视频编码器实例
    OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault, self.config.size.width, self.config.size.height, self.config.codecType, NULL, NULL, NULL, compressionOutputCallBack, (__bridge void *)self, &_compressionSession);
    if (status != noErr) {
        return status;
    }
    // 设置编码器属性--实时编码
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, (__bridge CFTypeRef)(@YES));
    // 设置编码器属性--编码格式
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, (__bridge CFStringRef)self.config.profileLevel);
    // 设置编码器蛇形--是否支持 B 帧
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, (__bridge CFTypeRef)@(self.config.openBFrame));
    if (self.config.codecType == kCMVideoCodecType_H264) {
        // 设置编码器属性--熵编码
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    }
    // 设置编码器属性--画面填充模式
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_PixelTransferProperties, (__bridge CFTypeRef)(@{(__bridge NSString *)kVTPixelTransferPropertyKey_ScalingMode : (__bridge NSString *)kVTScalingMode_Letterbox}));
    // 设置编码器属性--平均码率
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(self.config.bitrate));
    
    if (self.config.codecType == kCMVideoCodecType_H264 && !self.config.openBFrame) {
        // 设置码率上限
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(self.config.bitrate * 1.5 / 8), @(1)]);
    }
    // 设置编码器属性--期望帧率
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(self.config.fps));
    // 设置编码器属性--最大关键帧间隔帧数，GOP帧数
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(self.config.gopSize));
    // 设置编码器属性--最大关键帧时间间隔
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(self.config.gopSize / self.config.fps));
    // 准备编码
    status = VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    return status;
}

- (void)destoryCompressionSession {
    if (_compressionSession) {
        // 强制处理完所有帧
        VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }
}

static void compressionOutputCallBack(void * outputCallbackRefCon,
                                      void * sourceFrameRefCon,
                                      OSStatus status,
                                      VTEncodeInfoFlags infoFlags,
                                    CMSampleBufferRef sampleBuffer) {
    if (sampleBuffer != NULL) {
        XPYVideoEncoder *encoder = (__bridge XPYVideoEncoder *)outputCallbackRefCon;
        if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(videoEncoderDidOutputSampleBuffer:)]) {
            [encoder.delegate videoEncoderDidOutputSampleBuffer:sampleBuffer];
        }
    }
}

@end

@implementation XPYVideoEncoderConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _size = CGSizeMake(720, 1280);
        _fps = 30;
        _bitrate = 720 * 1280 * _fps * 0.15;
        _gopSize = _fps * 5;
        _openBFrame = YES;
        BOOL supportHEVC = NO;
        if (@available(iOS 11.0, *)) {
            if (&VTIsHardwareDecodeSupported) {
                supportHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
            }
        }
        _codecType = supportHEVC ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264;
        if (@available(iOS 11.0, *)) {
            _profileLevel = supportHEVC ? (__bridge NSString *)kVTProfileLevel_HEVC_Main_AutoLevel : (__bridge NSString *)kVTProfileLevel_H264_High_AutoLevel;
        } else {
            _profileLevel = (__bridge NSString *)kVTProfileLevel_H264_High_AutoLevel;
        }
        
    }
    return self;
}

@end
