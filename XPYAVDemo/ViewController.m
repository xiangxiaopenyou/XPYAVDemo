//
//  ViewController.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/3/11.
//

#import "ViewController.h"
#import <XPYAVKit/XPYAVKit.h>

@interface ViewController ()<XPYAudioCaptureDelegate>

@property (nonatomic, strong) XPYAudioCapture *audioCapture;

@end

@implementation ViewController {
    BOOL running;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (running) {
        [self.audioCapture stopCapturing];
    } else {
        [self.audioCapture startCapturing];
    }
    running = !running;
}

- (void)audioCaptureDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) {
        return;
    }
    // 数据转换
    size_t lengthAtOffsetOut, totalLengthOut;
    char *dataPointOut;
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffsetOut, &totalLengthOut, &dataPointOut);
    NSData *audioData = [NSData dataWithBytes:dataPointOut length:totalLengthOut];
}

- (void)audioCaptureError:(NSError *)error {
    
}

- (XPYAudioCapture *)audioCapture {
    if (!_audioCapture) {
        _audioCapture = [[XPYAudioCapture alloc] init];
        _audioCapture.delegate = self;
    }
    return _audioCapture;
}


@end
