//
//  XPYMuxerViewController.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/12.
//

#import "XPYMuxerViewController.h"
#import "XPYFrameProducer.h"
#import <FURenderKit/FURenderKit.h>
#import <XPYAVKit/XPYAVKit.h>

@interface XPYMuxerViewController ()<XPYVideoDecoderDelegate>

@property (nonatomic, strong) XPYMediaReader *reader;
@property (nonatomic, strong) XPYVideoDecoder *videoDecoder;
//@property (nonatomic, strong) XPYVideoFrameSorter *videoFrameSorter;

@property (nonatomic, strong) FUGLDisplayView *displayView;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic, strong) XPYFrameProducer *producer;

@end

@implementation XPYMuxerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [startButton setTitle:@"开始" forState:UIControlStateNormal];
    [startButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startAction:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:startButton];
    
    self.displayView = [[FUGLDisplayView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.displayView];
    
    
    
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"final_video" ofType:@"mp4"]];
    self.producer = [[XPYFrameProducer alloc] initWithMediaURL:url];
//    XPYMediaReaderConfig *config = [XPYMediaReaderConfig new];
//    config.mediaType = XPYMediaTypeVideo;
//    self.reader = [[XPYMediaReader alloc] initWithURL:url config:config];
//    
//    self.videoDecoder = [[XPYVideoDecoder alloc] init];
//    self.videoDecoder.delegate = self;

    self.semaphore = dispatch_semaphore_create(1);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (_displayLink) {
        [self.displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)dealloc {
    NSLog(@"----dealloc----");
}


CFAbsoluteTime last = 0;
- (void)display:(CADisplayLink *)sender {
    if (self.reader.hasVideoSampleBuffer) {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        CMSampleBufferRef sampleBuffer = [self.reader copyNextVideoSampleBuffer];
        if (sampleBuffer) {
            [self.videoDecoder decodeSampleBuffer:sampleBuffer];
        }
    }
    if (self.reader.status == AVAssetReaderStatusCompleted) {
        NSLog(@"🪐解封完成");
        [self.displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)startAction:(UIButton *)sender {
    [self.producer startWithCompletion:^(BOOL success) {
        
    }];
//    [self.reader startWithCompletion:^(BOOL success, NSError * _Nonnull error) {
//        if (success) {
//            dispatch_async(dispatch_get_global_queue(0, 0), ^{
//                self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(display:)];
//                [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
//                self.displayLink.preferredFramesPerSecond = self.reader.frameRate;
//                [[NSRunLoop currentRunLoop] run];
//            });
//        }
//        dispatch_async(dispatch_get_global_queue(0, 0), ^{
//            while (self.reader.hasVideoSampleBuffer) {
//                CMSampleBufferRef sampleBuffer = [self.reader copyNextVideoSampleBuffer];
//                if (sampleBuffer) {
//                    [self.videoDecoder decodeSampleBuffer:sampleBuffer];
//                }
//            }
//            if (self.reader.status == AVAssetReaderStatusCompleted) {
//                NSLog(@"🪐解封完成");
//            }
//        });
//    }];
}

- (void)videoDecoderDidOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp {
    if (self.displayView.origintation != (FUGLDisplayViewOrientation)[XPYAVUtils videoOrientationForTransform:self.reader.transform]) {
        self.displayView.origintation = (FUGLDisplayViewOrientation)[XPYAVUtils videoOrientationForTransform:self.reader.transform];
    }
    [self.displayView displayPixelBuffer:pixelBuffer];
    dispatch_semaphore_signal(self.semaphore);
//    self.displayView.origintation = self.reader.transform;
//    [self.videoFrameSorter addVideoFrame:pixelBuffer time:timeStamp];
}

@end
