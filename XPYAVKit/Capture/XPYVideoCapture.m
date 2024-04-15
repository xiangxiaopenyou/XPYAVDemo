//
//  XPYVideoCapture.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/20.
//

#import "XPYVideoCapture.h"

@interface XPYVideoCapture ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) XPYVideoCaptureConfig *config;
@property (nonatomic, strong) AVCaptureSession *captureSession; // 采集会话
@property (nonatomic, strong) AVCaptureDevice *captureDevice;   // 采集设备
@property (nonatomic, strong) AVCaptureDeviceInput *captureFrontInput;  // 前置摄像头输入
@property (nonatomic, strong) AVCaptureDeviceInput *captureBackInput;   // 后置摄像头输入
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoOutput; // 采集数据输出
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t videoCaptureQueue;

@end

@implementation XPYVideoCapture

- (instancetype)init {
    return [self initWithConfig:[XPYVideoCaptureConfig new]];
}

- (instancetype)initWithConfig:(XPYVideoCaptureConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        _videoCaptureQueue = dispatch_queue_create("com.xpy.videoCaptureQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)startCapturing {
    
    dispatch_async(self.videoCaptureQueue, ^{
        AVCaptureSession *session = self.captureSession;
        if (!session) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(videoCaptureError:)]) {
                [self.delegate videoCaptureError:[NSError errorWithDomain:NSStringFromClass(self.class) code:-1 userInfo:@{NSLocalizedDescriptionKey : @"创建会话失败"}]];
            }
            return;
        }
        if (!self.captureSession.isRunning) {
            [self.captureSession startRunning];
        }
    });
}

- (void)stopCapturing {
    dispatch_async(self.videoCaptureQueue, ^{
        if (!self->_captureSession) {
            return;
        }
        if (self->_captureSession.isRunning) {
            [self->_captureSession stopRunning];
        }
    });
}

- (BOOL)switchDevicePosition:(AVCaptureDevicePosition)position {
    return YES;
}

#pragma mark - Private methods

// 更新视频画面方向
- (void)updateOrientation {
    AVCaptureConnection *connection = [self.captureVideoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported && connection.videoOrientation != self.config.orientation) {
        connection.videoOrientation = self.config.orientation;
    }
}

// 更新是否镜像
- (void)updateMirror {
    AVCaptureConnection *connection = [self.captureVideoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoMirroringSupported && connection.isVideoMirrored != self.config.mirrored) {
        connection.videoMirrored = self.config.mirrored;
    }
}

- (void)updateActiveFrameDuration {
    [self.captureDevice lockForConfiguration:nil];
    // 帧率设置大于 30 时，需要先找到满足该帧率且设备支持的 AVCaptureDeviceFormat
    if (self.config.fps > 30) {
        NSArray<AVCaptureDeviceFormat *> *formats = self.captureDevice.formats;
        
        for (AVCaptureDeviceFormat *format in formats) {
            CMFormatDescriptionRef description = format.formatDescription;
            // 获取尺寸
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(description);
            // 最大支持帧率
            float maxRate = format.videoSupportedFrameRateRanges[0].maxFrameRate;
            // 当前尺寸
            CMVideoDimensions activeDimensions = CMVideoFormatDescriptionGetDimensions(self.captureDevice.activeFormat.formatDescription);
            if (maxRate > self.config.fps && CMFormatDescriptionGetMediaSubType(description) == self.config.formatType && dimensions.width * dimensions.height == activeDimensions.width * activeDimensions.height) {
                self.captureDevice.activeFormat = format;
                break;
            }
        }
    }
    
    CMTime duration = CMTimeMake(1, (int32_t)self.config.fps);
    
    __block BOOL supported = NO;
    [self.captureDevice.activeFormat.videoSupportedFrameRateRanges enumerateObjectsUsingBlock:^(AVFrameRateRange * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CMTimeCompare(duration, obj.minFrameDuration) >=0 && CMTimeCompare(duration, obj.maxFrameDuration) <= 0) {
            supported = YES;
            *stop = YES;
        }
    }];
    if (supported) {
        [self.captureDevice setActiveVideoMinFrameDuration:duration];
        [self.captureDevice setActiveVideoMaxFrameDuration:duration];
    }
    [self.captureDevice unlockForConfiguration];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output == self.captureVideoOutput) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoCaptureDidOutputSampleBuffer:)]) {
            [self.delegate videoCaptureDidOutputSampleBuffer:sampleBuffer];
        }
    }
}

#pragma mark - Utility

- (AVCaptureDevice *)deviceWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    NSArray *devices = session.devices;
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

#pragma mark - Getters

- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        AVCaptureDeviceInput *input = self.config.position == AVCaptureDevicePositionFront ? self.captureFrontInput : self.captureBackInput;
        if (!input) {
            return nil;
        }
        _captureSession = [[AVCaptureSession alloc] init];
        // 采集输入
        if ([_captureSession canAddInput:input]) {
            [_captureSession addInput:input];
        }
        if ([_captureSession canSetSessionPreset:self.config.preset]) {
            [_captureSession setSessionPreset:self.config.preset];
        } else {
            [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
        }
        // 采集输出
        if ([_captureSession canAddOutput:self.captureVideoOutput]) {
            [_captureSession addOutput:self.captureVideoOutput];
        }
        // 其他设置
        [self updateOrientation];
        [self updateMirror];
        [self updateActiveFrameDuration];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoCaptureDidCreateSession)]) {
            [self.delegate videoCaptureDidCreateSession];
        }
    }
    return _captureSession;
}

- (AVCaptureDevice *)captureDevice {
    return [self deviceWithPosition:self.config.position];
}

- (AVCaptureDeviceInput *)captureFrontInput {
    if (!_captureFrontInput) {
        _captureFrontInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self deviceWithPosition:AVCaptureDevicePositionFront] error:nil];
    }
    return _captureFrontInput;
}

- (AVCaptureDeviceInput *)captureBackInput {
    if (!_captureBackInput) {
        _captureBackInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self deviceWithPosition:AVCaptureDevicePositionBack] error:nil];
    }
    return _captureBackInput;
}

- (AVCaptureVideoDataOutput *)captureVideoOutput {
    if (!_captureVideoOutput) {
        _captureVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_captureVideoOutput setSampleBufferDelegate:self queue:self.videoCaptureQueue];
        _captureVideoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(self.config.formatType)};
        _captureVideoOutput.alwaysDiscardsLateVideoFrames = YES;    // 下一帧到来时丢弃未处理完的帧
    }
    return _captureVideoOutput;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    if (!_captureSession) {
        return nil;
    }
    if (!_previewLayer) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    }
    return _previewLayer;
}

@end

@implementation XPYVideoCaptureConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _fps = 30;
        _preset = AVCaptureSessionPreset1280x720;
        _position = AVCaptureDevicePositionFront;
        _orientation = AVCaptureVideoOrientationPortrait;
        _formatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        _mirrored = YES;
    }
    return self;
}

@end
