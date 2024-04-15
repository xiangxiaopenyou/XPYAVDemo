//
//  XPYRenderView.h
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//

#import <UIKit/UIKit.h>
#import <XPYAVKit/XPYTextureFrame.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, XPYGLContentMode) {
    XPYGLContentModeStretch = 0,    // 自动充满
    XPYGLContentModeFit,    // 按比例适配
    XPYGLContentModeFill    // 按比例裁剪充满
};

@interface XPYRenderView : UIView

@property (nonatomic, assign) XPYGLContentMode contentMode;

/// 允许外部上下文环境
- (instancetype)initWithFrame:(CGRect)frame context:(nullable EAGLContext *)context;

- (void)displayTexture:(XPYTextureFrame *)texture;


@end

NS_ASSUME_NONNULL_END
