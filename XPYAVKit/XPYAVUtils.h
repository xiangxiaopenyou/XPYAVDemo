//
//  XPYAVUtils.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

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

@end

NS_ASSUME_NONNULL_END
