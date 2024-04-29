////
////  XPYVideoFrameSorter.h
////  XPYAVKit
////
////  Created by MoMo on 2024/4/18.
////
//
//#import <AVFoundation/AVFoundation.h>
//
//NS_ASSUME_NONNULL_BEGIN
//
//@interface XPYVideoFrameSorter : NSObject
//
///// 数量到达最大容量并排序后进入 ready 为 YES，排序帧吐完以后恢复为 NO
//@property (nonatomic, assign, readonly, getter=isReader) BOOL ready;
//
//- (instancetype)initWithCapacity:(NSInteger)capacity;
//
///// 添加帧数据
///// @note 当数量到达最大容量时进行排序
//- (void)addVideoFrame:(CVPixelBufferRef)buffer time:(CMTime)pts;
//
//@end
//
//NS_ASSUME_NONNULL_END
