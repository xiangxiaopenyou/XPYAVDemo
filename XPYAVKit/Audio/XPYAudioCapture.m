//
//  XPYAudioCapture.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//

#import "XPYAudioCapture.h"
#import "XPYAVUtils.h"
#import <mach/mach_time.h>

@interface XPYAudioCapture ()

@property (nonatomic, strong) XPYAudioCaptureConfig *config;
/// 开始/停止采集操作串行队列
@property (nonatomic, strong) dispatch_queue_t captureQueue;
/// 音频采集实例
@property (nonatomic, assign) AudioComponentInstance audioCaptureInstance;

@property (nonatomic, assign) AudioStreamBasicDescription audioStreamDescription;

@end

@implementation XPYAudioCapture

- (instancetype)init {
    return [self initWithConfig:[XPYAudioCaptureConfig new]];
}

- (instancetype)initWithConfig:(XPYAudioCaptureConfig *)config {
    self = [super init];
    if (self) {
        BOOL setup = [XPYAVUtils setupAudioSession];
        NSAssert(setup, @"Setup audio session failed!");
        _config = config;
        _captureQueue = dispatch_queue_create("com.xpy.audioCaptureQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    if (_audioCaptureInstance) {
        AudioOutputUnitStop(_audioCaptureInstance);
        AudioComponentInstanceDispose(_audioCaptureInstance);
        _audioCaptureInstance = NULL;
    }
}

- (void)startCapturing {
    dispatch_async(self.captureQueue, ^{
        if (!self.audioCaptureInstance) {
            NSError *error = nil;
            [self createAudioCaptureInstance:&error];
            if (error && self.delegate && [self.delegate respondsToSelector:@selector(audioCaptureError:)]) {
                [self.delegate audioCaptureError:error];
                return;
            }
        }
        // 开始采集
        OSStatus status = AudioOutputUnitStart(self.audioCaptureInstance);
        if (status != noErr) {
            NSError *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
            if (self.delegate && [self.delegate respondsToSelector:@selector(audioCaptureError:)]) {
                [self.delegate audioCaptureError:error];
            }
        }
    });
    
}

- (void)stopCapturing {
    dispatch_async(self.captureQueue, ^{
        // 停止采集
        OSStatus status = AudioOutputUnitStop(self.audioCaptureInstance);
        if (status != noErr) {
            NSError *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
            if (self.delegate && [self.delegate respondsToSelector:@selector(audioCaptureError:)]) {
                [self.delegate audioCaptureError:error];
            }
        }
    });
}

/// 创建音频采集实例
- (void)createAudioCaptureInstance:(NSError **)error {
    // 音频组件配置
    AudioComponentDescription description = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    
    // 查找符合的音频组件
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    
    // 创建音频组件实例
    OSStatus status = AudioComponentInstanceNew(component, &_audioCaptureInstance);
    if (status != noErr) {
        // 创建失败
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    // 开启 Input Bus（采集只需要 Element1）
    UInt32 input_enable = 1;
    status = AudioUnitSetProperty(_audioCaptureInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, XPYInputBus, &input_enable, sizeof(input_enable));
    if (status != noErr) {
        // 开启 Input Bus 失败
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    // 关闭 Output Bus（Element0）
    UInt32 output_disable = 0;
    AudioUnitSetProperty(_audioCaptureInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, XPYOutputBus, &output_disable, sizeof(output_disable));
    
    // 设置音频流属性
    AudioStreamBasicDescription basicDescription = {0};
    basicDescription.mFormatID = kAudioFormatLinearPCM; // PCM 声道交错格式
    basicDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    basicDescription.mChannelsPerFrame = (UInt32)self.config.channelsNumber; // 每一帧的声道数
    basicDescription.mFramesPerPacket = 1;  // 每个数据包的帧数
    basicDescription.mBitsPerChannel = (UInt32)self.config.bitDepth;    // 量化位深
    basicDescription.mBytesPerFrame = basicDescription.mChannelsPerFrame * basicDescription.mBitsPerChannel / 8;    // 每一帧的字节数
    basicDescription.mBytesPerPacket = basicDescription.mFramesPerPacket * basicDescription.mBytesPerFrame; // 每一个包的字节数
    basicDescription.mSampleRate = self.config.samplingRate;    // 采样率
    self.audioStreamDescription = basicDescription;
    status = AudioUnitSetProperty(_audioCaptureInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, XPYInputBus, &basicDescription, sizeof(basicDescription));
    if (status != noErr) {
        // 设置音频流属性失败
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    // 设置数据回调
    AURenderCallbackStruct callBack;
    callBack.inputProcRefCon = (__bridge void *)self;
    callBack.inputProc = audioCaptureCallBack;
    status = AudioUnitSetProperty(_audioCaptureInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, XPYInputBus, &callBack, sizeof(callBack));
    if (status != noErr) {
        // 设置数据回调失败
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
    
    // 初始化实例
    status = AudioUnitInitialize(_audioCaptureInstance);
    if (status != noErr) {
        // 初始化实例失败
        *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:status userInfo:nil];
        return;
    }
}

/// 数据回调
static OSStatus audioCaptureCallBack(void *                            inRefCon,
                                     AudioUnitRenderActionFlags *    ioActionFlags,
                                     const AudioTimeStamp *            inTimeStamp,
                                     UInt32                            inBusNumber,
                                     UInt32                            inNumberFrames,
                                     AudioBufferList * __nullable    ioData) {
    XPYAudioCapture *capture = (__bridge XPYAudioCapture *)inRefCon;
    if (!capture) {
        return -1;
    }
    
    // 初始化 AudioBufferList 接收采集数据
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = 1; // 声道交错格式情况下就算是双声道也需要设置为1
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    
    // 获取音频数据（每帧声道数2 位深16bit 则每帧为4byte）
    // 数据回调的频率跟采样率无关
    OSStatus status = AudioUnitRender(capture.audioCaptureInstance, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &buffers);
    if (status != noErr) {
        return status;
    }
    CMSampleBufferRef sampleBuffer = [XPYAVUtils sampleBufferFromAudioBufferList:buffers timeStamp:inTimeStamp numberFrames:inNumberFrames description:capture.audioStreamDescription];
    if (!sampleBuffer) {
        return -1;
    }
    // 回调
    if (capture.delegate && [capture.delegate respondsToSelector:@selector(audioCaptureDidOutputSampleBuffer:)]) {
        [capture.delegate audioCaptureDidOutputSampleBuffer:sampleBuffer];
    }
    // 释放
    CFRelease(sampleBuffer);
    return status;
}

@end

@implementation XPYAudioCaptureConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _channelsNumber = 2;
        _samplingRate = 44100;
        _bitDepth = 16;
    }
    return self;
}

@end

