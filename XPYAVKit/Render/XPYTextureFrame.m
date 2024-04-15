//
//  XPYTextureFrame.m
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//

#import "XPYTextureFrame.h"

@implementation XPYTextureFrame

- (instancetype)initWithId:(GLuint)textureId size:(CGSize)textureSize time:(CMTime)time {
    self = [super init];
    if (self) {
        _textureId = textureId;
        _textureSize = textureSize;
        _time = time;
        _mvpMatrix = GLKMatrix4Identity;
    }
    return self;
}

@end
