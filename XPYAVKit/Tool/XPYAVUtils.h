//
//  XPYAVUtils.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 媒体类型
typedef NS_ENUM(NSInteger, XPYMediaType) {
    XPYMediaTypeNone = 0,
    XPYMediaTypeAudio = 1 << 0,  // 单音频
    XPYMediaTypeVideo = 1 << 1,  // 单视频
    XPYMediaTypeBoth = XPYMediaTypeAudio | XPYMediaTypeVideo   // 音视频
};

typedef NS_ENUM(NSUInteger, XPYVideoOrientation) {
    XPYVideoOrientationPortrait = 0,
    XPYVideoOrientationRight,
    XPYVideoOrientationUpsideDown,
    XPYVideoOrientationLeft
};

extern const AudioUnitElement XPYOutputBus;

extern const AudioUnitElement XPYInputBus;

@interface XPYAVUtils : NSObject

/// 根据 AudioBufferList 生成 CMSampleBuffer
+ (CMSampleBufferRef)sampleBufferFromAudioBufferList:(AudioBufferList)buffers
                                           timeStamp:(const AudioTimeStamp *)timeStamp
                                        numberFrames:(UInt32)numberFrames
                                         description:(AudioStreamBasicDescription)description;

/// AVAudioSession 默认配置
+ (BOOL)setupAudioSession;

/// 判断是否关键帧
+ (BOOL)isKeyFrame:(CMSampleBufferRef)sampleBuffer;

/// 根据 Transform 获取视频画面朝向
+ (XPYVideoOrientation)videoOrientationForTransform:(CGAffineTransform)transform;

@end

NS_ASSUME_NONNULL_END
