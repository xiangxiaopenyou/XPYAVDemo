//
//  XPYRenderView.m
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//

#import "XPYRenderView.h"

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface XPYRenderView ()

// 纹理大小
@property (nonatomic, assign) CGSize textureSize;
// 视图大小
@property (nonatomic, assign) CGSize viewSize;

@end

@implementation XPYRenderView {
    // 画布宽高
    GLint backingWidth;
    GLint backingHeight;
    
    GLuint frameBuffer;
    GLuint renderBuffer;
    
    GLfloat vertices[8];
}

- (instancetype)initWithFrame:(CGRect)frame context:(EAGLContext *)context {
    self = [super initWithFrame:frame];
    if (self) {
        CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
        glLayer.opaque = YES;
        glLayer.drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking : @NO,
            kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
        };
        if (context) {
            EAGLContext *preContext = [EAGLContext currentContext];
            [EAGLContext setCurrentContext:context];
            
        }
    }
    return self;
}

- (void)setupGL {
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    
    [[EAGLContext currentContext] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
    
    
    
//    glFramebufferRenderbuffer(<#GLenum target#>, <#GLenum attachment#>, <#GLenum renderbuffertarget#>, <#GLuint renderbuffer#>)
    
//    CVopenglestexture
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

@end
