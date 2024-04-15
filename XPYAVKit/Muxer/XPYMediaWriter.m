//
//  XPYMediaWriter.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/26.
//

#import "XPYMediaWriter.h"

@interface XPYMediaWriter ()

@property (nonatomic, strong) NSURL *mediaURL;
@property (nonatomic, strong) XPYMediaWriterConfig *config;
@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;

@property (nonatomic, strong) dispatch_queue_t writerQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end

@implementation XPYMediaWriter {
    CMSimpleQueueRef videoQueue, audioQueue;
}

#pragma mark - Life cycle

- (instancetype)initWithVideoURL:(NSURL *)URL setting:(XPYMediaWriterConfig *)config {
    self = [super init];
    if (self) {
        _mediaURL = URL;
        _config = config;
        
        _writerQueue = dispatch_queue_create("com.xpy.mediaWriterQueue", DISPATCH_QUEUE_SERIAL);
        _semaphore = dispatch_semaphore_create(1);
        
        // 根据配置初始化队列
        if (config.mediaType & XPYMediaTypeVideo) {
            CMSimpleQueueCreate(kCFAllocatorDefault, 10000, &videoQueue);
        }
        if (config.mediaType & XPYMediaTypeAudio) {
            CMSimpleQueueCreate(kCFAllocatorDefault, 10000, &audioQueue);
        }
    }
    return self;
}

- (void)dealloc {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [self destoryWriter];
    dispatch_semaphore_signal(self.semaphore);
}

#pragma mark - Public methods

- (void)start {
    dispatch_async(self.writerQueue, ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        // 先清理
        [self destoryWriter];
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)cancel {
    dispatch_async(self.writerQueue, ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        if (self.writer.status == AVAssetWriterStatusWriting) {
            [self.writer cancelWriting];
        }
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (sampleBuffer == NULL || CMSampleBufferGetDataBuffer(sampleBuffer) == NULL || !_writer) {
        return;
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(self.writerQueue, ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        // 添加数据到队列，先保存
        CFRetain(sampleBuffer);
        // 需要确保格式正确才能入队
        if (CMFormatDescriptionGetMediaType(CMSampleBufferGetFormatDescription(sampleBuffer)) == kCMMediaType_Video) {
            CMSimpleQueueEnqueue(self->videoQueue, sampleBuffer);
        } else if (CMFormatDescriptionGetMediaType(CMSampleBufferGetFormatDescription(sampleBuffer)) == kCMMediaType_Audio) {
            CMSimpleQueueEnqueue(self->audioQueue, sampleBuffer);
        }
        // 未创建封装器
        if (!self->_writer) {
            // 判断队列数据格式
            if (![self checkFormat]) {
                CFRelease(sampleBuffer);
                dispatch_semaphore_signal(self.semaphore);
                return;
            }
            // 创建封装器
            [self createWriter];
            if (!self->_writer) {
                CFRelease(sampleBuffer);
                dispatch_semaphore_signal(self.semaphore);
                return;
            }
            // 开始写入
            BOOL success = [self.writer startWriting];
            if (!success) {
                CFRelease(sampleBuffer);
                dispatch_semaphore_signal(self.semaphore);
                return;
            }
            [self.writer startSessionAtSourceTime:[self startingSourceTime]];
        }
        
        // 处理队列中的数据
        [self write];
        
        CFRelease(sampleBuffer);
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)finishWithCompletion:(void (^)(BOOL, NSError *))completion {
    if (!self.writer || self.writer.status != AVAssetWriterStatusWriting) {
        !completion ?: completion(NO, [NSError errorWithDomain:NSStringFromClass(self.class) code:self.writer ? self.writer.status : -1 userInfo:nil]);
    }
    if (CMSimpleQueueGetCount(videoQueue) > 0 || CMSimpleQueueGetCount(audioQueue) > 0) {
        // 需要消费掉队列里剩余音视频数据
        [self write];
        [self writeAudio];
        [self writeVideo];
    }
    // 标记为结束状态
    if (_audioInput) {
        [self.audioInput markAsFinished];
    }
    if (_videoInput) {
        [self.videoInput markAsFinished];
    }
    [self.writer finishWritingWithCompletionHandler:^{
        !completion ?: completion(YES, nil);
    }];
}

#pragma mark - Private methods

- (void)write {
    // 交错封装音视频，可以提升播放体验
    if ((self.config.mediaType & XPYMediaTypeVideo) && (self.config.mediaType & XPYMediaTypeAudio)) {
        while (CMSimpleQueueGetCount(videoQueue) > 0 && CMSimpleQueueGetCount(audioQueue) > 0) {
            if (!self.videoInput.isReadyForMoreMediaData || !self.audioInput.isReadyForMoreMediaData) {
                // 输入源未准备好
                break;
            }
            // 各取一帧
            CMSampleBufferRef videoBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(videoQueue);
            CMSampleBufferRef audioBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(audioQueue);
            CMTime videoTime = CMSampleBufferGetPresentationTimeStamp(videoBuffer);
            CMTime audioTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
            // 写入较小者
            if (CMTimeGetSeconds(videoTime) >= CMTimeGetSeconds(audioTime)) {
                CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(audioQueue);
                [self.audioInput appendSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
            } else {
                CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(videoQueue);
                [self.videoInput appendSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
            }
            
        }
    } else if (self.config.mediaType & XPYMediaTypeVideo) {
        [self writeVideo];
    } else if (self.config.mediaType & XPYMediaTypeAudio) {
        [self writeAudio];
    }
}

- (void)writeVideo {
    while (CMSimpleQueueGetCount(videoQueue) > 0 && self.videoInput.isReadyForMoreMediaData) {
        // 写入视频帧
        CMSampleBufferRef videoBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(videoQueue);
        [self.videoInput appendSampleBuffer:videoBuffer];
        CFRelease(videoBuffer);
    }
}

- (void)writeAudio {
    while (CMSimpleQueueGetCount(audioQueue) > 0 && self.audioInput.isReadyForMoreMediaData) {
        // 写入音频帧
        CMSampleBufferRef audioBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(audioQueue);
        [self.audioInput appendSampleBuffer:audioBuffer];
        CFRelease(audioBuffer);
    }
}

/// 判断队列数据格式是否正确
- (BOOL)checkFormat {
    if ((self.config.mediaType & XPYMediaTypeVideo) && (self.config.mediaType & XPYMediaTypeAudio)) {
        return CMSimpleQueueGetCount(videoQueue) > 0 && CMSimpleQueueGetCount(audioQueue);
    } else if (self.config.mediaType & XPYMediaTypeVideo) {
        return CMSimpleQueueGetCount(videoQueue) > 0;
    } else if (self.config.mediaType & XPYMediaTypeAudio) {
        return CMSimpleQueueGetCount(audioQueue) > 0;
    }
    return NO;
}

/// 计算因视频 PTS 的最小值
- (CMTime)startingSourceTime {
    if ((self.config.mediaType & XPYMediaTypeVideo) && (self.config.mediaType & XPYMediaTypeAudio)) {
        CMSampleBufferRef videoBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(videoQueue);
        CMSampleBufferRef audioBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(audioQueue);
        return CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(videoBuffer)) >= CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(audioBuffer)) ? CMSampleBufferGetPresentationTimeStamp(audioBuffer) : CMSampleBufferGetPresentationTimeStamp(videoBuffer);
    } else if (self.config.mediaType & XPYMediaTypeVideo) {
        CMSampleBufferRef videoBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(videoQueue);
        return CMSampleBufferGetPresentationTimeStamp(videoBuffer);
    } else if (self.config.mediaType & XPYMediaTypeAudio) {
        CMSampleBufferRef audioBuffer = (CMSampleBufferRef)CMSimpleQueueGetHead(audioQueue);
        return CMSampleBufferGetPresentationTimeStamp(audioBuffer);
    }
    return kCMTimeInvalid;
}

- (void)createWriter {
    if (!self.mediaURL) {
        return;
    }
    
    // 如果文件已经存在，先删除旧文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.mediaURL.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:self.mediaURL error:nil];
    }
    
    if (_writer) {
        return;
    }
    
    NSError *error;
    _writer = [[AVAssetWriter alloc] initWithURL:self.mediaURL fileType:self.config.fileType error:&error];
    if (error) {
        // 创建封装器失败
        return;
    }
    // 网络优化 Moov box 前置
    _writer.shouldOptimizeForNetworkUse = YES;
    // 默认封装时间为10s，大于10s时需要设置为kCMTimeInvalid
    _writer.movieFragmentInterval = kCMTimeInvalid;
    // 视频输入
    if ((self.config.mediaType & XPYMediaTypeVideo) && !_videoInput) {
        // 从视频队列中取得头部数据，用于初始化视频输入源
        CMVideoFormatDescriptionRef description = CMSampleBufferGetFormatDescription((CMSampleBufferRef)CMSimpleQueueGetHead(videoQueue));
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil sourceFormatHint:description];
        _videoInput.expectsMediaDataInRealTime = self.config.isRealTimeData;
        _videoInput.transform = self.config.transform;
        if ([_writer canAddInput:_videoInput]) {
            [_writer addInput:_videoInput];
        } else {
            return;
        }
    }
    // 音频输入
    if ((self.config.mediaType & XPYMediaTypeAudio) && !_audioInput) {
        // 从音频队列中取得头部数据，用于初始化音频输入源
        CMVideoFormatDescriptionRef description = CMSampleBufferGetFormatDescription((CMSampleBufferRef)CMSimpleQueueGetHead(audioQueue));
        _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:nil sourceFormatHint:description];
        _audioInput.expectsMediaDataInRealTime = self.config.isRealTimeData;
        if ([_writer canAddInput:_audioInput]) {
            [_writer addInput:_audioInput];
        } else {
            return;
        }
    }
    
}

- (void)destoryWriter {
    if (_writer.status == AVAssetWriterStatusWriting) {
        [_writer cancelWriting];
    }
    
    _writer = nil;
    _videoInput = nil;
    _audioInput = nil;
    
    // 清理音视频队列
    if (videoQueue != NULL) {
        while (CMSimpleQueueGetCount(videoQueue) > 0) {
            CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(videoQueue);
            CFRelease(sampleBuffer);
        }
    }
    if (audioQueue != NULL) {
        while (CMSimpleQueueGetCount(audioQueue) > 0) {
            CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(audioQueue);
            CFRelease(sampleBuffer);
        }
    }
}


@end

@implementation XPYMediaWriterConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        self.mediaType = XPYMediaTypeBoth;
        self.fileType = AVFileTypeQuickTimeMovie;
        self.isRealTimeData = NO;
        self.transform = CGAffineTransformIdentity;
        self.videoInputFormat = AVVideoCodecH264;
        self.audioInputFormat = kAudioFormatMPEG4AAC;
        self.audioChannels = 2;
        self.audioRate = [AVAudioSession sharedInstance].sampleRate;
    }
    return self;
}

@end
