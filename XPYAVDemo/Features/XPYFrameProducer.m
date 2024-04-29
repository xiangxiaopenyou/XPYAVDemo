//
//  XPYFrameProducer.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/28.
//

#import "XPYFrameProducer.h"
#import <XPYAVKit/XPYAVKit.h>

@interface XPYVideoFrame : NSObject

+ (instancetype)createFrame:(CVPixelBufferRef)pixelBuffer time:(CMTime)pts;

@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, assign) CMTime pts;

@end

@implementation XPYVideoFrame

+ (instancetype)createFrame:(CVPixelBufferRef)pixelBuffer time:(CMTime)pts {
    if (!pixelBuffer) {
        return nil;
    }
    XPYVideoFrame *frame = [XPYVideoFrame new];
    frame.pixelBuffer = pixelBuffer;
    frame.pts = pts;
    return frame;
}

@end

@interface XPYFrameProducer () <XPYVideoDecoderDelegate>

@property (nonatomic, strong) XPYMediaReader *reader;
@property (nonatomic, strong) XPYVideoDecoder *videoDecoder;
//@property (nonatomic, assign) NSInteger capacity;
@property (nonatomic, strong) NSMutableArray *frames;

@property (nonatomic, assign) NSUInteger framesCount;

@property (nonatomic, strong) dispatch_semaphore_t framesSemaphore;

@end

@implementation XPYFrameProducer

- (instancetype)initWithMediaURL:(NSURL *)mediaURL {
    self = [super init];
    if (self) {
        XPYMediaReaderConfig *config = [XPYMediaReaderConfig new];
        config.mediaType = XPYMediaTypeVideo;
        self.reader = [[XPYMediaReader alloc] initWithURL:mediaURL config:config];
        
        self.videoDecoder = [[XPYVideoDecoder alloc] init];
        self.videoDecoder.delegate = self;
        
        _frames = [[NSMutableArray alloc] init];
        _capacity = 80;
        _framesSemaphore = dispatch_semaphore_create(1);
        
    }
    return self;
}

- (void)startWithCompletion:(void (^)(BOOL))completion {
    [self.reader startWithCompletion:^(BOOL success, NSError * _Nonnull error) {
        if (!success) {
            !completion ?: completion(NO);
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self productFrame];
                if (self.framesCount > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        !completion ?: completion(YES);
                    });
                }
            });
        }
    }];
}

/// 请求帧
- (void)productFrame {
    while (self.framesCount < self.capacity && self.reader.hasVideoSampleBuffer) {
        CMSampleBufferRef sampleBuffer = [self.reader copyNextVideoSampleBuffer];
        NSLog(@"-------%lu----", (unsigned long)self.framesCount);
        if (sampleBuffer) {
            [self.videoDecoder decodeSampleBuffer:sampleBuffer];
        }
    }
}

#pragma mark - XPYVideoDecoderDelegate

- (void)videoDecoderDidOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp {
    dispatch_semaphore_wait(self.framesSemaphore, DISPATCH_TIME_FOREVER);
    CVPixelBufferRetain(pixelBuffer);
    XPYVideoFrame *frame = [XPYVideoFrame createFrame:pixelBuffer time:timeStamp];
    [self.frames addObject:frame];
    dispatch_semaphore_signal(self.framesSemaphore);
}

#pragma mark - Getters

- (NSUInteger)framesCount {
    NSUInteger count;
    dispatch_semaphore_wait(self.framesSemaphore, DISPATCH_TIME_FOREVER);
    count = self.frames.count;
    dispatch_semaphore_signal(self.framesSemaphore);
    return count;
}

@end
