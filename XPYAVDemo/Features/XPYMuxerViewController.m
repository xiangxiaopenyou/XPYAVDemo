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

@property (nonatomic, strong) FUGLDisplayView *displayView;

@property (nonatomic, strong) CADisplayLink *displayLink;

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
    self.displayView.contentMode = FUGLDisplayViewContentModeScaleAspectFit;
    [self.view addSubview:self.displayView];
    
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"final_video" ofType:@"mp4"]];
    self.producer = [[XPYFrameProducer alloc] initWithMediaURL:url];
    self.producer.needsSorting = NO;
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
    CVPixelBufferRef pixelBuffer = [self.producer getNextPixelBuffer];
    if (!pixelBuffer) {
        [self.displayLink invalidate];
        _displayLink = nil;
        return;
    }
    CFAbsoluteTime current = CFAbsoluteTimeGetCurrent();
    if (last != 0) {
        double diff = current - last;
        NSLog(@"----%.3f----", diff);
    }
    last = current;
    if (pixelBuffer) {
        if (self.displayView.origintation != (FUGLDisplayViewOrientation)[XPYAVUtils videoOrientationForTransform:self.producer.reader.transform]) {
            self.displayView.origintation = (FUGLDisplayViewOrientation)[XPYAVUtils videoOrientationForTransform:self.producer.reader.transform];
        }
        [self.displayView displayPixelBuffer:pixelBuffer];
        CVPixelBufferRelease(pixelBuffer);
    }
//    if (self.reader.hasVideoSampleBuffer) {
//        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
//        CMSampleBufferRef sampleBuffer = [self.reader copyNextVideoSampleBuffer];
//        if (sampleBuffer) {
//            [self.videoDecoder decodeSampleBuffer:sampleBuffer];
//        }
//    }
//    if (self.reader.status == AVAssetReaderStatusCompleted) {
//        NSLog(@"🪐解封完成");
//        [self.displayLink invalidate];
//        _displayLink = nil;
//    }
}

- (void)startAction:(UIButton *)sender {
    [self.producer startWithCompletion:^(BOOL success) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(display:)];
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.displayLink.preferredFramesPerSecond = self.producer.reader.frameRate;
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
//    if (self.displayView.origintation != (FUGLDisplayViewOrientation)[XPYAVUtils videoOrientationForTransform:self.reader.transform]) {
//        self.displayView.origintation = (FUGLDisplayViewOrientation)[XPYAVUtils videoOrientationForTransform:self.reader.transform];
//    }
//    [self.displayView displayPixelBuffer:pixelBuffer];
}

@end
