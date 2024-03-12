//
//  XPYAudioConfig.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/11.
//

#import "XPYAudioConfig.h"

@implementation XPYAudioConfig

+ (instancetype)defaultConfig {
    XPYAudioConfig *config = [[XPYAudioConfig alloc] init];
    config.channelsNumber = 2;
    config.samplingRate = 44100;
    config.bitDepth = 16;
    return config;
}

@end
