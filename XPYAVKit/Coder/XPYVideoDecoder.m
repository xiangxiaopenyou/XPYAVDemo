//
//  XPYVideoDecoder.m
//  XPYAVKit
//
//  Created by MoMo on 2024/4/12.
//

#import "XPYVideoDecoder.h"

#import "XPYAVUtils.h"
#import <VideoToolbox/VideoToolbox.h>

static const NSInteger kXPYDecoderMaxRetrySessionCount = 5;

static const NSInteger kXPYDecoderMaxDecodeFaildCount = 10;

@interface XPYVideoFrameData : NSObject

@property (nonatomic, assign) CMSampleBufferRef sampleBuffer;

@end

@interface XPYVideoDecoder ()

@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
/// 允许重试次数
@property (nonatomic, assign) NSInteger retrySessionCount;
/// 允许失败次数
@property (nonatomic, assign) NSInteger decodeFaildCount;
/// 保存 GOP 序列的数组
@property (nonatomic, strong) NSMutableArray<XPYVideoFrameData *> *gops;
@property (nonatomic, assign) NSInteger inputCount;
@property (nonatomic, assign) NSInteger outputCount;

@property (nonatomic, strong) dispatch_queue_t decoderQueue;
@property (nonatomic, strong) dispatch_semaphore_t decoderSemaphore;


@end

@implementation XPYVideoDecoder

- (instancetype)init {
    self = [super init];
    if (self) {
        _decoderQueue = dispatch_queue_create("com.xpy.decoderQueue", DISPATCH_QUEUE_SERIAL);
        _decoderSemaphore = dispatch_semaphore_create(1);
        _gops = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    dispatch_semaphore_wait(self.decoderSemaphore, DISPATCH_TIME_FOREVER);
    [self destoryDecompressionSession];
    [self clearGOP];
    dispatch_semaphore_signal(self.decoderSemaphore);
}

- (void)decodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer || _retrySessionCount > kXPYDecoderMaxRetrySessionCount || _decodeFaildCount > kXPYDecoderMaxDecodeFaildCount) {
        return;
    }
    dispatch_async(self.decoderQueue, ^{
        dispatch_semaphore_wait(self.decoderSemaphore, DISPATCH_TIME_FOREVER);
        
        OSStatus status = noErr;
        if (!self->_decompressionSession) {
            status = [self createDecompressionSession:CMSampleBufferGetFormatDescription(sampleBuffer)];
            if (status != noErr) {
                self.retrySessionCount += 1;
                [self destoryDecompressionSession];
                if (self.retrySessionCount > kXPYDecoderMaxRetrySessionCount) {
                    // 重试次数超过限制
                    CFRelease(sampleBuffer);
                    dispatch_semaphore_signal(self.decoderSemaphore);
                    if (self.delegate && [self.delegate respondsToSelector:@selector(videoDecoderError:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate videoDecoderError:[NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil]];
                        });
                    }
                }
                return;
            }
            self.retrySessionCount = 0;
        }
        
        // 解码当前帧
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags infoFlags = 0;
        OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(self.decompressionSession, sampleBuffer, flags, NULL, &infoFlags);
        if (decodeStatus == kVTInvalidSessionErr) {
            // 解码失败，重建解码器重试
            [self destoryDecompressionSession];
            status = [self createDecompressionSession:CMSampleBufferGetFormatDescription(sampleBuffer)];
            if (status != noErr) {
                // 重建失败
                self.retrySessionCount += 1;
                [self destoryDecompressionSession];
            } else {
                self.retrySessionCount = 0;
                // 重建成功后需要从当前 GOP 开始的 I 帧解码，这里先解码当前缓存的一个 GOP 的所有帧
                flags = kVTDecodeFrame_DoNotOutputFrame;
                if (self.gops.count > 0) {
                    for (XPYVideoFrameData *data in self.gops) {
                        VTDecompressionSessionDecodeFrame(self.decompressionSession, data.sampleBuffer, flags, NULL, &infoFlags);
                    }
                }
                // 解码当前帧
                flags = kVTDecodeFrame_EnableAsynchronousDecompression;
                decodeStatus = VTDecompressionSessionDecodeFrame(self.decompressionSession, sampleBuffer, flags, NULL, &infoFlags);
            }
        } else if (decodeStatus != noErr) {
            // 其他错误导致解码当前帧失败，暂不处理
        }
        
        if ([XPYAVUtils isKeyFrame:sampleBuffer]) {
            // 关键帧（I帧），需要清空 GOP ，开始新的序列缓存
            [self clearGOP];
        }
        XPYVideoFrameData *frameData = [XPYVideoFrameData new];
        frameData.sampleBuffer = sampleBuffer;
        [self.gops addObject:frameData];
        
        // 记录解码失败次数
        self.decodeFaildCount = decodeStatus == noErr ? 0 : self.decodeFaildCount + 1;
        
        dispatch_semaphore_signal(self.decoderSemaphore);
        if (self.decodeFaildCount > kXPYDecoderMaxDecodeFaildCount) {
            // 解码失败次数超过限制
            if (self.delegate && [self.delegate respondsToSelector:@selector(videoDecoderError:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate videoDecoderError:[NSError errorWithDomain:NSStringFromClass(self.class) code:decodeStatus userInfo:nil]];
                });
            }
        }
    });
}

#pragma mark - Private methods

- (void)clearGOP {
    for (XPYVideoFrameData *data in self.gops) {
        if (data.sampleBuffer) {
            CFRelease(data.sampleBuffer);
        }
    }
    [self.gops removeAllObjects];
}

- (OSStatus)createDecompressionSession:(CMFormatDescriptionRef)description {
    // 颜色格式
    NSDictionary *dictionary = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    
    // 回调结构体
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decompressionOutputCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void *)self;
    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault, description, NULL, (__bridge CFDictionaryRef)dictionary, &callbackRecord, &_decompressionSession);
    return status;
}

- (void)destoryDecompressionSession {
    if (_decompressionSession) {
        // 等待所有帧完成
        VTDecompressionSessionWaitForAsynchronousFrames(_decompressionSession);
        VTDecompressionSessionInvalidate(_decompressionSession);
        _decompressionSession = NULL;
    }
}


static void decompressionOutputCallback(void * decompressionOutputRefCon,
                           void * sourceFrameRefCon,
                           OSStatus status,
                           VTDecodeInfoFlags infoFlags,
                           CVImageBufferRef imageBuffer,
                           CMTime presentationTimeStamp,
                           CMTime presentationDuration ) {
    if (status != noErr) {
        return;
    }
    if (infoFlags & kVTDecodeInfo_FrameDropped) {
        return;
    }
    XPYVideoDecoder *decoder = (__bridge XPYVideoDecoder *)decompressionOutputRefCon;
    if (decoder && imageBuffer) {
        if (decoder.delegate && [decoder.delegate respondsToSelector:@selector(videoDecoderDidOutputPixelBuffer:timeStamp:)]) {
            [decoder.delegate videoDecoderDidOutputPixelBuffer:imageBuffer timeStamp:presentationTimeStamp];
        }
    }
}

@end

@implementation XPYVideoFrameData

@end

