//
//  XPYFrameProducer.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/28.
//

#import "XPYFrameProducer.h"
#import "XPYVideoFrameList.h"

@interface XPYFrameProducer () <XPYVideoDecoderDelegate>

@property (nonatomic, strong) XPYMediaReader *reader;
@property (nonatomic, strong) XPYVideoDecoder *videoDecoder;
/// 缓存表，双缓存提高效率
@property (nonatomic, strong) XPYVideoFrameList *cache1;
@property (nonatomic, strong) XPYVideoFrameList *cache2;

/// 对外顺序吐帧表指针，默认指向 cache1，之后在 cache1 和 cache2 之间切换
@property (nonatomic, strong) XPYVideoFrameList *output;
/// 加载 GOP 缓存表指针，在 cache1 和 cache2 之间切换，用于异步提前加载下一个 GOP
@property (nonatomic, strong) XPYVideoFrameList *producing;

@property (nonatomic, strong) dispatch_semaphore_t produceSemaphore;

@end

@implementation XPYFrameProducer

- (instancetype)initWithMediaURL:(NSURL *)mediaURL {
    self = [super init];
    if (self) {
        XPYMediaReaderConfig *config = [XPYMediaReaderConfig new];
        config.mediaType = XPYMediaTypeVideo;
        config.videoBufferFormat = XPYVideoBufferFormat420f;
        self.reader = [[XPYMediaReader alloc] initWithURL:mediaURL config:config];
        
        self.videoDecoder = [[XPYVideoDecoder alloc] init];
        self.videoDecoder.delegate = self;
        
        self.cache1 = [[XPYVideoFrameList alloc] init];
        self.cache2 = [[XPYVideoFrameList alloc] init];
        
        _capacity = 10;
        _produceSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)dealloc {
    // 释放缓存视频帧占用内存
    if (self.cache1.count > 0) {
        [self.cache1 free];
    }
    if (self.cache2.count > 0) {
        [self.cache2 free];
    }
}

- (void)startWithCompletion:(void (^)(BOOL))completion {
    [self.reader startWithCompletion:^(BOOL success, NSError * _Nonnull error) {
        if (!success) {
            !completion ?: completion(NO);
        } else {
            if (!self.reader.hasVideoSampleBuffer) {
                !completion ?: completion(NO);
                return;
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 首次启动时加载两个 GOP 缓存
                self.producing = self.cache1;
                [self produceFrame];
                self.producing = self.cache2;
                [self produceFrame];
                self.output = self.cache1;
                dispatch_async(dispatch_get_main_queue(), ^{
                    !completion ?: completion(YES);
                });
            });
        }
    }];
}

- (CVPixelBufferRef)getNextPixelBuffer {
    if (self.output.count > 0) {
        XPYVideoFrameNode *frame = [self.output nextNode];
        if (frame) {
            CVPixelBufferRef pixelBuffer = frame.pixelBuffer;
            if (self.output.count == 0) {
                // 交换指针
                if (self.output == self.cache1) {
                    self.output = self.cache2;
                    self.producing = self.cache1;
                } else {
                    self.output = self.cache1;
                    self.producing = self.cache2;
                }
                // 异步加载下一个 GOP
                if (self.reader.hasVideoSampleBuffer) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self produceFrame];
                    });
                }
            }
            return pixelBuffer;
        }
    }
    return NULL;
}

#pragma mark - Private methods

/// 请求帧
- (void)produceFrame {
    while (self.producing.count < self.capacity && self.reader.hasVideoSampleBuffer) {
        CMSampleBufferRef sampleBuffer = [self.reader copyNextVideoSampleBuffer];
        if (CMSampleBufferGetImageBuffer(sampleBuffer)) {
            // CVImageBuffer 直接保存
            [self savePixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) timeStamp:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        } else if (CMSampleBufferGetDataBuffer(sampleBuffer)) {
            // 解码
            [self.videoDecoder decodeSampleBuffer:sampleBuffer];
        } else {
            // 无效数据
            dispatch_semaphore_signal(self.produceSemaphore);
        }
        dispatch_semaphore_wait(self.produceSemaphore, DISPATCH_TIME_FOREVER);
    }
    if (self.needsSorting) {
        [self.producing sort];
    }
}

- (void)savePixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp {
    // Retain
//    CVPixelBufferRetain(pixelBuffer);
    XPYVideoFrameNode *frame = [XPYVideoFrameNode createFrame:pixelBuffer time:timeStamp];
    [self.producing addNode:frame];
    dispatch_semaphore_signal(self.produceSemaphore);
}

#pragma mark - XPYVideoDecoderDelegate

- (void)videoDecoderDidOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp {
    [self savePixelBuffer:pixelBuffer timeStamp:timeStamp];
}

@end
