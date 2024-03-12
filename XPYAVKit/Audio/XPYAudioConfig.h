//
//  XPYAudioConfig.h
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//
//  音频采集参数配置类

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XPYAudioConfig : NSObject

/// 声道数，默认为 2
@property (nonatomic, assign) NSUInteger channelsNumber;
/// 采样率，默认为 44100
@property (nonatomic, assign) NSUInteger samplingRate;
/// 量化位深，默认为 16
@property (nonatomic, assign) NSUInteger bitDepth;

/// 默认配置
+ (instancetype)defaultConfig;

@end

NS_ASSUME_NONNULL_END
