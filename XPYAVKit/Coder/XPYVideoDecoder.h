//
//  XPYVideoDecoder.h
//  XPYAVKit
//
//  Created by MoMo on 2024/4/12.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol XPYVideoDecoderDelegate <NSObject>

/// 视频解码帧数据回调
- (void)videoDecoderDidOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)timeStamp;

@optional
/// 视频解码错误回调
- (void)videoDecoderError:(NSError *)error;

@end

@interface XPYVideoDecoder : NSObject

@property (nonatomic, weak) id<XPYVideoDecoderDelegate> delegate;

- (void)decodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
