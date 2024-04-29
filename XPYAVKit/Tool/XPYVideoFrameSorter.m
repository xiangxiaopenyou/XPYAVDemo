////
////  XPYVideoFrameSorter.m
////  XPYAVKit
////
////  Created by MoMo on 2024/4/18.
////
//
//#import "XPYVideoFrameSorter.h"
//
//@interface XPYVideoFrame : NSObject
//
//+ (instancetype)createFrame:(CVPixelBufferRef)pixelBuffer time:(CMTime)pts;
//
//@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
//@property (nonatomic, assign) CMTime pts;
//
//@end
//
//@implementation XPYVideoFrame
//
//+ (instancetype)createFrame:(CVPixelBufferRef)pixelBuffer time:(CMTime)pts {
//    if (!pixelBuffer) {
//        return nil;
//    }
//    XPYVideoFrame *frame = [XPYVideoFrame new];
//    frame.pixelBuffer = pixelBuffer;
//    frame.pts = pts;
//    return frame;
//}
//
//@end
//
//@interface XPYVideoFrameSorter ()
//
//@property (nonatomic, assign) NSInteger capacity;
//@property (nonatomic, strong) NSMutableArray<XPYVideoFrame *> *frames;
//@property (nonatomic, strong) NSLock *lock;
//
//@end
//
//@implementation XPYVideoFrameSorter
//
//- (instancetype)init {
//    return [self initWithCapacity:5];
//}
//
//- (instancetype)initWithCapacity:(NSInteger)capacity {
//    self = [super init];
//    if (self) {
//        _capacity = capacity;
//        _frames = [[NSMutableArray alloc] init];
//        _lock = [[NSLock alloc] init];
//    }
//    return self;
//}
//
//- (void)addVideoFrame:(CVPixelBufferRef)buffer time:(CMTime)pts {
//    if (!buffer) {
//        return;
//    }
//    [self.lock lock];
//    CVPixelBufferRetain(buffer);
//    XPYVideoFrame *frame = [XPYVideoFrame createFrame:buffer time:pts];
//    [self.frames addObject:frame];
//    [self.lock unlock];
//    if (self.frames.count == self.capacity) {
//        // 需要排序
//        [self sort];
//        // 向外面吐帧
//        for (XPYVideoFrame *frame in self.frames) {
//            NSLog(@"✨%lld", frame.pts.value);
//            CVPixelBufferRelease(frame.pixelBuffer);
//        }
//    }
//    
//}
//
//- (void)sort {
//    // 简单排序
//    [self.lock lock];
//    for (int i = 0; i < self.frames.count; i++) {
//        for (int j = 0; j < self.frames.count - i - 1; j++) {
//            XPYVideoFrame *frame1 = self.frames[j];
//            XPYVideoFrame *frame2 = self.frames[j+1];
//            if (frame1.pts.value > frame2.pts.value) {
//                XPYVideoFrame *temp = [XPYVideoFrame new];
//                temp.pixelBuffer = frame1.pixelBuffer;
//                temp.pts = frame1.pts;
//                self.frames[j] = self.frames[j+1];
//                self.frames[j+1] = temp;
//            }
//        }
//    }
//    [self.lock unlock];
//}
//
//@end
