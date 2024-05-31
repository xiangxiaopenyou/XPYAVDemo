//
//  XPYVideoFrameList.h
//  XPYAVDemo
//
//  Created by 项林平 on 2024/5/8.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/* 链表结构 */
@interface XPYVideoFrameNode : NSObject
/// 下一节点
@property (nonatomic, strong, nullable) XPYVideoFrameNode *next;
/// 帧数据
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
/// 显示时间，作为排序使用
@property (nonatomic, assign) CMTime pts;

+ (instancetype)createFrame:(CVPixelBufferRef)pixelBuffer time:(CMTime)pts;

@end

/* 缓存表*/
@interface XPYVideoFrameList : NSObject
/// 头节点
@property (nonatomic, strong, readonly) XPYVideoFrameNode *head;
/// 尾节点
@property (nonatomic, strong, readonly) XPYVideoFrameNode *tail;
/// 节点数量
@property (nonatomic, assign, readonly) NSUInteger count;

/// 增加节点
- (void)addNode:(XPYVideoFrameNode *)node;

/// 拼接链表
- (void)appendList:(XPYVideoFrameList *)list;

/// 获取下一节点
- (XPYVideoFrameNode *)nextNode;

/// 根据 pts 排序
- (void)sort;

/// 释放内存
- (void)free;

@end

NS_ASSUME_NONNULL_END
