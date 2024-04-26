//
//  XPYMediaReader.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/28.
//

#import "XPYMediaReader.h"

static const int kXPYMaximumNumberInQueue = 3;

@interface XPYMediaReader ()

@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) XPYMediaReaderConfig *config;

@property (nonatomic, assign) BOOL containsAudioTrack;
@property (nonatomic, assign) BOOL containsVideoTrack;
@property (nonatomic, assign) BOOL audioFinished;
@property (nonatomic, assign) BOOL videoFinished;
@property (nonatomic, assign) NSInteger frameRate;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CMVideoCodecType codecType;
@property (nonatomic, assign) CGAffineTransform transform;

@property (nonatomic, strong) dispatch_queue_t readerQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
// 视频队列操作信号
@property (nonatomic, strong) dispatch_semaphore_t videoSemaphore;
// 音频队列操作信号
@property (nonatomic, strong) dispatch_semaphore_t audioSemaphore;

@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderTrackOutput *audioOutput;

@end

@implementation XPYMediaReader {
    CMSimpleQueueRef audioQueue;
    CMSimpleQueueRef videoQueue;
    CMTime lastVideoTime;   // 上次加载的视频帧时间戳
    CMTime lastAudioTime;   // 上次加载的音频帧时间戳
}

#pragma mark - Initializer

- (instancetype)initWithURL:(NSURL *)URL {
    return [self initWithURL:URL config:[XPYMediaReaderConfig new]];
}

- (instancetype)initWithURL:(NSURL *)URL config:(XPYMediaReaderConfig *)config {
    NSAssert(URL, @"URL cannot be nil!");
    NSDictionary *options = @{AVURLAssetPreferPreciseDurationAndTimingKey : @YES};
    return [self initWithAsset:[[AVURLAsset alloc] initWithURL:URL options:options] config:config];
}

- (instancetype)initWithAsset:(AVAsset *)asset {
    return [self initWithAsset:asset config:[XPYMediaReaderConfig new]];
}

- (instancetype)initWithAsset:(AVAsset *)asset config:(XPYMediaReaderConfig *)config {
    self = [super init];
    if (self) {
        NSAssert(asset, @"Asset cannot be nil!");
        self.asset = asset;
        if (!config) {
            self.config = [[XPYMediaReaderConfig alloc] init];
        } else {
            self.config = config;
        }
        _readerQueue = dispatch_queue_create("com.xpy.readerQueue", DISPATCH_QUEUE_SERIAL);
        _semaphore = dispatch_semaphore_create(1);
        self.videoSemaphore = dispatch_semaphore_create(1);
        self.audioSemaphore = dispatch_semaphore_create(1);
        CMSimpleQueueCreate(kCFAllocatorDefault, kXPYMaximumNumberInQueue, &videoQueue);
        CMSimpleQueueCreate(kCFAllocatorDefault, kXPYMaximumNumberInQueue, &audioQueue);
    }
    return self;
}

- (void)dealloc {
    // 清理封装器实例
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_reader && _reader.status == AVAssetReaderStatusReading) {
        [self.reader cancelReading];
    }
    dispatch_semaphore_signal(_semaphore);
    
    // 清理视频数据队列
    dispatch_semaphore_wait(self.videoSemaphore, DISPATCH_TIME_FOREVER);
    while (CMSimpleQueueGetCount(videoQueue) > 0) {
        CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(videoQueue);
        CFRelease(sampleBuffer);
        sampleBuffer = NULL;
    }
    dispatch_semaphore_signal(self.videoSemaphore);
    
    // 清理音频数据队列
    dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER);
    while (CMSimpleQueueGetCount(audioQueue) > 0) {
        CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(audioQueue);
        CFRelease(sampleBuffer);
        sampleBuffer = NULL;
    }
    dispatch_semaphore_signal(self.audioSemaphore);
}

- (void)startWithCompletion:(void (^)(BOOL, NSError *))completion {
    dispatch_async(_readerQueue, ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        if (!self->_reader) {
            NSError *error = nil;
            [self createReader:&error];
            self.videoFinished = !self.containsVideoTrack;
            self.audioFinished = !self.containsAudioTrack;
            dispatch_semaphore_signal(self.semaphore);
            dispatch_async(dispatch_get_main_queue(), ^{
                !completion ?: completion(error ? NO : YES, error);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            !completion ?: completion(YES, nil);
        });
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)cancel {
    dispatch_async(_readerQueue, ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        if (self->_reader && self->_reader.status == AVAssetReaderStatusReading) {
            [self.reader cancelReading];
        }
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (BOOL)hasVideoSampleBuffer {
    if (self.containsVideoTrack && self.reader.status == AVAssetReaderStatusReading && !self.videoFinished) {
        return YES;
    }
    return NO;
}

- (CMSampleBufferRef)copyNextVideoSampleBuffer {
    CMSampleBufferRef sampleBuffer = NULL;
    while (!sampleBuffer && self.reader.status == AVAssetReaderStatusReading && !self.videoFinished) {
        dispatch_semaphore_wait(self.videoSemaphore, DISPATCH_TIME_FOREVER);
        // 先从缓冲队列里取数据
        if (CMSimpleQueueGetCount(videoQueue) > 0) {
            sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(videoQueue);
        }
        dispatch_semaphore_signal(self.videoSemaphore);
        if (sampleBuffer == NULL) {
            // 队列里取不到，则同步加载
            [self loadNextSampleBufferSync];
        }
    }
    // 每次异步加载一帧缓存到队列
    [self loadNextSampleBufferAsync];
    
    return sampleBuffer;
}

- (BOOL)hasAudioSampleBuffer {
    if (self.containsAudioTrack && self.reader.status == AVAssetReaderStatusReading && !self.audioFinished) {
        return YES;
    }
    return NO;
}

- (CMSampleBufferRef)copyNextAudioSampleBuffer {
    CMSampleBufferRef sampleBuffer = NULL;
    while (!sampleBuffer && self.reader.status == AVAssetReaderStatusReading && !self.audioFinished) {
        dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER);
        // 先从缓冲队列里取数据
        if (CMSimpleQueueGetCount(audioQueue) > 0) {
            sampleBuffer = (CMSampleBufferRef)CMSimpleQueueDequeue(audioQueue);
        }
        dispatch_semaphore_signal(self.audioSemaphore);
        if (sampleBuffer == NULL) {
            // 队列里取不到，则同步加载
            [self loadNextSampleBufferSync];
        }
    }
    // 每次异步加载一帧缓存到队列
    [self loadNextSampleBufferAsync];
    return sampleBuffer;
}

#pragma mark - Private methods

- (void)loadNextSampleBufferSync {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [self loadNextSampleBuffer];
    dispatch_semaphore_signal(self.semaphore);
}

- (void)loadNextSampleBufferAsync {
    dispatch_async(self.readerQueue, ^{
        [self loadNextSampleBufferSync];
    });
}

- (void)loadNextSampleBuffer {
    if (self.reader.status == AVAssetReaderStatusCompleted ||
        self.reader.status == AVAssetReaderStatusCancelled ||
        self.reader.status == AVAssetReaderStatusUnknown) {
        return;
    }
    
    if (self.reader.status == AVAssetReaderStatusFailed) {
        if (self.reader.error.code == AVErrorOperationInterrupted) {
            // 被打断的情况下，需要重新创建
            NSError *error;
            [self createReader:&error];
            if (!error) {
                // 恢复上次位置
                [self resumeReader];
            }
        }
        if (self.reader.status == AVAssetReaderStatusFailed) {
            // 还是错误状态则报错
            dispatch_async(dispatch_get_main_queue(), ^{
                !self.readerError ?: self.readerError(self.reader.error);
            });
            return;
        }
    }
    
    // 正常加载下一帧流程
    BOOL needLoadingVideo = (self.config.mediaType & XPYMediaTypeVideo) && !_videoFinished;
    BOOL needLoadingAudio = (self.config.mediaType & XPYMediaTypeAudio) && !_audioFinished;
    while (self.reader.status == AVAssetReaderStatusReading && (needLoadingAudio || needLoadingVideo)) {
        if (needLoadingVideo) { // 加载视频下一帧
            dispatch_semaphore_wait(self.videoSemaphore, DISPATCH_TIME_FOREVER);
            int videoCount = CMSimpleQueueGetCount(videoQueue);
            dispatch_semaphore_signal(self.videoSemaphore);
            if (videoCount < kXPYMaximumNumberInQueue) {
                // 当前视频队列中的帧数小于最大限制，需要取帧入队
                CMSampleBufferRef sampleBuffer = [self.videoOutput copyNextSampleBuffer];
                if (sampleBuffer) {
                    if (CMSampleBufferGetDataBuffer(sampleBuffer)) {
                        dispatch_semaphore_wait(self.videoSemaphore, DISPATCH_TIME_FOREVER);
                        CMSimpleQueueEnqueue(videoQueue, sampleBuffer);
                        dispatch_semaphore_signal(self.videoSemaphore);
                    } else {
                        // 无效帧
                        CFRelease(sampleBuffer);
                    }
                } else {
                    self.videoFinished = self.reader.status == AVAssetReaderStatusCompleted || self.reader.status == AVAssetReaderStatusReading;
                    needLoadingVideo = NO;
                }
            } else {
                // 超过限制不需要取帧
                needLoadingVideo = NO;
            }
        }
        if (needLoadingAudio) { // 加载音频下一帧
            dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER);
            int audioCount = CMSimpleQueueGetCount(audioQueue);
            dispatch_semaphore_signal(self.audioSemaphore);
            if (audioCount < kXPYMaximumNumberInQueue) {
                CMSampleBufferRef sampleBuffer = [self.audioOutput copyNextSampleBuffer];
                if (sampleBuffer) {
                    if (CMSampleBufferGetDataBuffer(sampleBuffer)) {
                        dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER);
                        CMSimpleQueueEnqueue(audioQueue, sampleBuffer);
                        dispatch_semaphore_signal(self.audioSemaphore);
                    } else {
                        // 无效帧
                        CFRelease(sampleBuffer);
                    }
                } else {
                    self.audioFinished = self.reader.status == AVAssetReaderStatusCompleted || self.reader.status == AVAssetReaderStatusReading;
                    needLoadingAudio = NO;
                }
            } else {
                // 超过限制不需要取帧
                needLoadingAudio = NO;
            }
        }
    }
    
}

- (void)resumeReader {
    BOOL needLoadingVideo = _containsVideoTrack && lastVideoTime.value > 0 && !_videoFinished;
    BOOL needLoadingAudio = _containsAudioTrack && lastAudioTime.value > 0 && !_audioFinished;
    if (!needLoadingAudio && !needLoadingVideo) {
        return;
    }
    while (self.reader && self.reader.status == AVAssetReaderStatusReading && (needLoadingVideo || needLoadingAudio)) {
        if (needLoadingVideo) {
            CMSampleBufferRef sampleBuffer = [self.videoOutput copyNextSampleBuffer];
            if (sampleBuffer) {
                if (!CMSampleBufferGetDataBuffer(sampleBuffer) || CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) <= CMTimeGetSeconds(lastVideoTime)) {
                    // 取出的下一帧数据 PTS 小于保存的上一帧，表示已经被处理了，直接抛弃
                    CFRelease(sampleBuffer);
                } else {
                    dispatch_semaphore_wait(self.videoSemaphore, DISPATCH_TIME_FOREVER);
                    CMSimpleQueueEnqueue(videoQueue, sampleBuffer);
                    dispatch_semaphore_signal(self.videoSemaphore);
                    needLoadingVideo = NO;
                }
            }
        }
        if (needLoadingAudio) {
            CMSampleBufferRef sampleBuffer = [self.audioOutput copyNextSampleBuffer];
            if (sampleBuffer) {
                if (!CMSampleBufferGetDataBuffer(sampleBuffer) || CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) < CMTimeGetSeconds(lastAudioTime)) {
                    CFRelease(sampleBuffer);
                } else {
                    dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER);
                    CMSimpleQueueEnqueue(audioQueue, sampleBuffer);
                    dispatch_semaphore_signal(self.audioSemaphore);
                    needLoadingAudio = NO;
                }
            }
        }
    }
}

- (void)createReader:(NSError **)error {
    _reader = [[AVAssetReader alloc] initWithAsset:self.asset error:nil];
    if (!_reader) {
        return;
    }
    
    _duration = self.asset.duration;
    if (self.config.mediaType & XPYMediaTypeVideo) {
        // 视频轨道
        AVAssetTrack *videoTrack = [self.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        _containsVideoTrack = videoTrack ? YES : NO;
        if (_containsVideoTrack) {
            // 图像变换信息
            _transform = videoTrack.preferredTransform;
            
            // 帧率
            _frameRate = videoTrack.nominalFrameRate >= 1.0 ? (NSInteger)videoTrack.nominalFrameRate : 30;
            
            // 图像大小
            _videoSize = CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform);
            _videoSize = CGSizeMake(fabs(_videoSize.width), fabs(_videoSize.height));
            
            // 编码格式
            CMVideoFormatDescriptionRef description = (__bridge CMVideoFormatDescriptionRef)[videoTrack formatDescriptions].firstObject;
            if (description) {
                _codecType = CMVideoFormatDescriptionGetCodecType(description);
            }
            
            // 创建视频输出
            _videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:nil];
            _videoOutput.alwaysCopiesSampleData = NO;
            
            // 绑定视频输出
            if (![_reader canAddOutput:_videoOutput]) {
                *error = _reader.error ? _reader.error : [NSError errorWithDomain:NSStringFromClass(self.class) code:2001 userInfo:nil];
                return;
            }
            [_reader addOutput:_videoOutput];
        }
    }
    if (self.config.mediaType & XPYMediaTypeAudio) {
        // 音频轨道
        AVAssetTrack *audioTrack = [self.asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        _containsAudioTrack = audioTrack ? YES : NO;
        if (_containsAudioTrack) {
            _audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack outputSettings:nil];
            _audioOutput.alwaysCopiesSampleData = NO;
            
            // 绑定音频输出
            if (![_reader canAddOutput:_audioOutput]) {
                *error = _reader.error ? _reader.error : [NSError errorWithDomain:NSStringFromClass(self.class) code:2002 userInfo:nil];
                return;
            }
            [_reader addOutput:_audioOutput];
        }
    }
    
    if (!_containsVideoTrack && !_containsAudioTrack) {
        *error = _reader.error ? _reader.error : [NSError errorWithDomain:NSStringFromClass(self.class) code:2000 userInfo:nil];
        return;
    }
    
    BOOL success = [self.reader startReading];
    if (!success) {
        *error = self.reader.error;
    }
}

- (AVAssetReaderStatus)status {
    if (!_reader) {
        return AVAssetReaderStatusUnknown;
    }
    return self.reader.status;
}

@end

@implementation XPYMediaReaderConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _mediaType = XPYMediaTypeBoth;
    }
    return self;
}

@end
