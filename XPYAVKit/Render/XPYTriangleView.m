//
//  XPYTriangleView.m
//  XPYAVDemo
//
//  Created by MoMo on 2024/4/6.
//

#import "XPYTriangleView.h"
#import "XPYGLProgram.h"
#import "XPYGLShader.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

typedef struct {
    GLfloat position[3];
    GLfloat color[4];
} SceneVertex;

@interface XPYTriangleView ()

@property (nonatomic, strong) CAEAGLLayer *glLayer;
@property (nonatomic, strong) EAGLContext *glContext;

@property (nonatomic, assign) GLsizei width;
@property (nonatomic, assign) GLsizei height;

/// RBO
@property (nonatomic, assign) GLuint renderBuffer;
/// FBO
@property (nonatomic, assign) GLuint frameBuffer;
/// 链接程序
@property (nonatomic, strong) XPYGLProgram *program;

@end

@implementation XPYTriangleView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _width = CGRectGetWidth(frame);
        _height = CGRectGetHeight(frame);
        [self render];
    }
    return self;
}

- (void)render {
    // layer 类型
    _glLayer = (CAEAGLLayer *)self.layer;
    _glLayer.opaque = 1.0;
    _glLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking : @NO,
        kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
    };
    
    // OpenGL 上下文
    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!_glContext) {
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    NSAssert(_glContext, @"GL context is nil!");
    
    [EAGLContext setCurrentContext:_glContext];
    
    // 创建 RBO
    glGenRenderbuffers(1, &_renderBuffer);
    // 绑定 RBO
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    // 绑定渲染图层（glLayer）到 RBO
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_glLayer];
    
    // 创建 FBO
    glGenFramebuffers(1, &_frameBuffer);
    // 绑定 FBO
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    // 将 RBO 附着到 FBO，OpenGL 对 FBO 的绘制会同步到 RBO 再上屏
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    // 清理窗口颜色
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    // 设置渲染窗口区域
    glViewport(0, 0, _width, _height);
    
    _program = [[XPYGLProgram alloc] initWithVertexShader:XPYSimpleVertexShader fragmentShader:XPYSimpleFragmentShader];
    [_program use];
    
    // 三角形顶点数据（坐标和颜色）
    SceneVertex vertices[] = {
        {{-0.5, 0.5, 0.0}, {1.0, 0.0, 0.0, 1.0}},
        {{-0.5, -0.5, 0.0}, {0.0, 1.0, 0.0, 1.0}},
        {{0.5, -0.5, 0.0}, {0.0, 0.0, 1.0, 1.0}},
    };
    
    // 创建 VBO
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    // 绑定 VBO
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    // 将顶点数据从 CPU 拷贝到 GPU
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    // 获取参数位置信息
    int vertexPositionLocation = [_program attributeLocation:@"v_position"];
    int vertexColorLocation = [_program attributeLocation:@"v_color"];
    
    // 启用顶点位置属性通道
    glEnableVertexAttribArray(vertexPositionLocation);
    // 关联顶点位置数据
    glVertexAttribPointer(vertexPositionLocation, 3, GL_FLOAT, GL_FALSE, sizeof(SceneVertex), (const GLvoid *)offsetof(SceneVertex, position));
    
    // 启用颜色属性通道
    glEnableVertexAttribArray(vertexColorLocation);
    // 关联颜色数据
    glVertexAttribPointer(vertexColorLocation, 4, GL_FLOAT, GL_FALSE, sizeof(SceneVertex), (const GLvoid *)offsetof(SceneVertex, color));
    
    // 绘制三角形图元
    glDrawArrays(GL_TRIANGLES, 0, sizeof(vertices) / sizeof(vertices[0]));
    
    // 显示 RBO 内容到窗口
    [_glContext presentRenderbuffer:GL_RENDERBUFFER];
    
    // Clear
    glDisableVertexAttribArray(vertexPositionLocation);
    glDisableVertexAttribArray(vertexColorLocation);
    // 解绑 VBO
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    // 解绑 FBO
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    // 解绑 RBO
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

@end
