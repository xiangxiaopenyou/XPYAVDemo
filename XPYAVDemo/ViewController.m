//
//  ViewController.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/3/11.
//

#import "ViewController.h"
#import "XPYMuxerViewController.h"
#import <objc/runtime.h>
#import <XPYAVKit/XPYAVKit.h>

#define SHADER_STRING(text) @#text

@interface ViewController ()<XPYAudioCaptureDelegate, XPYVideoCaptureDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) XPYAudioCapture *audioCapture;
@property (nonatomic, strong) XPYVideoCapture *videoCapture;
@property (nonatomic, strong) XPYVideoEncoder *videoEncoder;

@end

@implementation ViewController {
    BOOL running;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    XPYTriangleView *triangle = [[XPYTriangleView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
//    [self.view addSubview:triangle];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AVCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AVCell"];
    }
    NSString *titleString;
    switch (indexPath.row) {
        case 0:
            titleString = @"采集";
            break;
        case 1:
            titleString = @"解封装器";
            break;
        default:
            break;
    }
    cell.textLabel.text = titleString;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
            break;
        case 1:{
            XPYMuxerViewController *muxerController = [[XPYMuxerViewController alloc] init];
            [self.navigationController pushViewController:muxerController animated:YES];
        }
            break;
        default:
            break;
    }
}

//- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    if (running) {
//        [self.videoCapture stopCapturing];
//    } else {
//        [self.videoCapture startCapturing];
//    }
//    running = !running;
//}

#pragma mark - XPYAudioCaptureDelegate
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

#pragma mark - XPYVideoCaptureDelegate

- (void)videoCaptureDidCreateSession {
    if (![self.view.layer.sublayers containsObject:self.videoCapture.previewLayer]) {
        self.videoCapture.previewLayer.frame = self.view.bounds;
        [self.view.layer addSublayer:self.videoCapture.previewLayer];
    }
}

- (void)videoCaptureDidOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (sampleBuffer != NULL) {
        [self.videoEncoder encodePixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) timeStamp:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
    }
}

- (void)videoCaptureError:(NSError *)error {
}

- (XPYAudioCapture *)audioCapture {
    if (!_audioCapture) {
        _audioCapture = [[XPYAudioCapture alloc] init];
        _audioCapture.delegate = self;
    }
    return _audioCapture;
}

- (XPYVideoCapture *)videoCapture {
    if (!_videoCapture) {
        _videoCapture = [[XPYVideoCapture alloc] init];
        _videoCapture.delegate = self;
    }
    return _videoCapture;
}

- (XPYVideoEncoder *)videoEncoder {
    if (!_videoEncoder) {
        _videoEncoder = [[XPYVideoEncoder alloc] init];
    }
    return _videoEncoder;
}

@end
