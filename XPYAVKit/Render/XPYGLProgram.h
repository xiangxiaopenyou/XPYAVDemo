//
//  XPYGLProgram.h
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//
//  GL 程序

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XPYGLProgram : NSObject

- (instancetype)initWithVertexShader:(NSString *)vertexString fragmentShader:(NSString *)fragmentString;

- (void)use;

/// 获取 uniform 位置值
- (int)uniformLocation:(NSString *)name;

/// 获取 attribute 位置值
- (int)attributeLocation:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
