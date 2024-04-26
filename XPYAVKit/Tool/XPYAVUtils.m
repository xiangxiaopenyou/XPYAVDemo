//
//  XPYAVUtils.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//

#import "XPYAVUtils.h"
#import <mach/mach.h>

const AudioUnitElement XPYOutputBus = 0;

const AudioUnitElement XPYInputBus = 1;

@implementation XPYAVUtils

+ (CMSampleBufferRef)sampleBufferFromAudioBufferList:(AudioBufferList)buffers 
                                           timeStamp:(const AudioTimeStamp *)timeStamp
                                        numberFrames:(UInt32)numberFrames
                                         description:(AudioStreamBasicDescription)description {
    // 音频流格式描述
    CMFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &description, 0, NULL, 0, NULL, NULL, &formatDescription);
    if (status != noErr) {
        CFRelease(formatDescription);
        return NULL;
    }
    
    // 处理时间戳
    mach_timebase_info_data_t timebase_info = {0, 0};
    mach_timebase_info(&timebase_info);
    UInt64 hostTime = timeStamp->mHostTime;
    // 纳秒
    hostTime *= timebase_info.numer / timebase_info.denom;
    // 显示时间戳
    CMTime presentationTime = CMTimeMake(hostTime, 1000000000.0f);
    // 音频的 PTS 和 DTS 相同
    CMSampleTimingInfo timing = {CMTimeMake(1, description.mSampleRate), presentationTime, presentationTime};
    
    // 创建 CMSampleBufferRef 实例
    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreate(kCFAllocatorDefault, NULL, false, NULL, NULL, formatDescription, numberFrames, 1, &timing, 0, NULL, &sampleBuffer);
    if (status != noErr) {
        CFRelease(formatDescription);
        return NULL;
    }
    
    // 拷贝音频数据
    status = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer, kCFAllocatorDefault, kCFAllocatorDefault, 0, &buffers);
    if (status != noErr) {
        CFRelease(formatDescription);
        return NULL;
    }
    CFRelease(formatDescription);
    return sampleBuffer;
}

+ (BOOL)setupAudioSession {
    NSError *error = nil;
    // 分类、模式、分类选项
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVideoRecording options:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (error) {
        return NO;
    }
    // 激活 session
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        return NO;
    }
    return YES;
}

+ (BOOL)isKeyFrame:(CMSampleBufferRef)sampleBuffer {
    CFArrayRef cfArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!cfArray) { return NO; }
    
    CFDictionaryRef dic = CFArrayGetValueAtIndex(cfArray, 0);
    if (!dic) { return NO; }
    
    BOOL contains = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    return contains;
}

+ (XPYVideoOrientation)videoOrientationForTransform:(CGAffineTransform)transform {
    if (transform.a == 1.0 && transform.d == 1.0 && transform.b == 0 && transform.c == 0) {
        return XPYVideoOrientationPortrait;
    } else if (transform.a == -1.0 && transform.d == 1.0 && transform.b == 0 && transform.c == 0) {
        return XPYVideoOrientationUpsideDown;
    } else if (transform.a == 0 && transform.d == 0 && transform.b == 1.0 && transform.c == -1.0) {
        return XPYVideoOrientationRight;
    } else if (transform.a == 0 && transform.d == 0 && transform.b == -1.0 && transform.c == 1.0) {
        return XPYVideoOrientationLeft;
    }
    return XPYVideoOrientationPortrait;
}

@end
