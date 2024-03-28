//
//  XPYAudioEncoder.m
//  XPYAVKit
//
//  Created by MoMo on 2024/3/15.
//

#import "XPYAudioEncoder.h"

@interface XPYAudioEncoder ()

@property (nonatomic, assign) NSInteger bitrate;

@property (nonatomic, strong) dispatch_queue_t encodeQueue;

@end

@implementation XPYAudioEncoder

- (instancetype)initWithBitrate:(NSInteger)bitrate {
    self = [super init];
    if (self) {
        _bitrate = bitrate;
        _encodeQueue = dispatch_queue_create("com.xpy.audioEncoderQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    
}

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) {
        return;
    }
    
}

@end
