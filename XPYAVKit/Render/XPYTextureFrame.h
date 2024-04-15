//
//  XPYTextureFrame.h
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//
//  纹理

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface XPYTextureFrame : NSObject

/// 纹理 ID
@property (nonatomic, assign) GLuint textureId;
/// 纹理尺寸
@property (nonatomic, assign) CGSize textureSize;
@property (nonatomic, assign) CMTime time;
@property (nonatomic, assign) GLKMatrix4 mvpMatrix;

- (instancetype)initWithId:(GLuint)textureId size:(CGSize)textureSize time:(CMTime)time;

@end

NS_ASSUME_NONNULL_END
