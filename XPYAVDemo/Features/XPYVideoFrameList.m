//
//  XPYVideoFrameList.m
//  XPYAVDemo
//
//  Created by 项林平 on 2024/5/8.
//

#import "XPYVideoFrameList.h"

@implementation XPYVideoFrameNode

+ (instancetype)createFrame:(CVPixelBufferRef)pixelBuffer time:(CMTime)pts {
    XPYVideoFrameNode *node = [XPYVideoFrameNode new];
    node.pixelBuffer = pixelBuffer;
    node.pts = pts;
    node.next = nil;
    return node;
}

@end

@interface XPYVideoFrameList ()

@property (nonatomic, strong) XPYVideoFrameNode *head;

@property (nonatomic, strong) XPYVideoFrameNode *tail;

@property (nonatomic, assign) NSUInteger count;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end

@implementation XPYVideoFrameList

- (instancetype)init {
    self = [super init];
    if (self) {
        _semaphore = dispatch_semaphore_create(1);
        _count = 0;
    }
    return self;
}

#pragma mark - Public methods

- (void)addNode:(XPYVideoFrameNode *)node {
    if (!node) {
        return;
    }
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    if (!_head) {
        self.head = node;
        self.tail = self.head;
    } else {
        // 加在表尾
        self.tail.next = node;
        self.tail = self.tail.next;
    }
    _count += 1;
    dispatch_semaphore_signal(self.semaphore);
}

- (void)appendList:(XPYVideoFrameList *)list {
    if (!list) { return; }
    if (!list.head || list.count == 0) { return; }
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    if (!_head) {
        self.head = list.head;
        self.tail = list.tail;
        _count = list.count;
    } else {
        // 拼接到尾部
        self.tail.next = list.head;
        self.tail = list.tail;
        _count += list.count;
    }
    dispatch_semaphore_signal(self.semaphore);
}

- (XPYVideoFrameNode *)nextNode {
    if (!_head) {
        return nil;
    }
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    XPYVideoFrameNode *node = self.head;
    // 头结点指向下一个节点
    self.head = self.head.next;
    _count -= 1;
    dispatch_semaphore_signal(self.semaphore);
    return node;
}

- (void)sort {
    if (_count <= 1) {
        return;
    }
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    self.head = [self subSort:self.head];
    XPYVideoFrameNode *node = self.head;
    while (node.next) {
        node = node.next;
    }
    self.tail = node;
    dispatch_semaphore_signal(self.semaphore);
}

- (void)free {
    if (_head) {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        XPYVideoFrameNode *node = self.head;
        while (node.pixelBuffer) {
            CVPixelBufferRelease(node.pixelBuffer);
            node = node.next;
        }
        dispatch_semaphore_signal(self.semaphore);
    }
}

#pragma mark - Private methods

/// 链表归并排序
/// 关键点：快慢指针找到链表中点
- (XPYVideoFrameNode *)subSort:(XPYVideoFrameNode *)head {
    if (!head || !head.next) {
        return head;
    }
    XPYVideoFrameNode *slow = head, *fast = head.next;
    while (fast != nil && fast.next != nil) {
        slow = slow.next;
        fast = fast.next.next;
    }
    
    // 得到中点
    XPYVideoFrameNode *mid = slow.next;
    // 断链
    slow.next = nil;
    // 分治
    XPYVideoFrameNode *node1 = [self subSort:head];
    XPYVideoFrameNode *node2 = [self subSort:mid];
    return [self subMerge:node1 listNode:node2];
}

/// 合并有序链表
- (XPYVideoFrameNode *)subMerge:(XPYVideoFrameNode *)l1 listNode:(XPYVideoFrameNode *)l2 {
    if (!l1) { return l2; }
    if (!l2) { return l1; }
    XPYVideoFrameNode *head = [XPYVideoFrameNode new];
    XPYVideoFrameNode *list = head;
    while (l1 && l2) {
        if (l1.pts.value <= l2.pts.value) {
            list.next = l1;
            l1 = l1.next;
        } else {
            list.next = l2;
            l2 = l2.next;
        }
        list = list.next;
    }
    if (l1) {
        list.next = l1;
    } else if (l2) {
        list.next = l2;
    }
    return head.next;
}

@end
