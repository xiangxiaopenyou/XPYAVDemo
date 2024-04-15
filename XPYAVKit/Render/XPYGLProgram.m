//
//  XPYGLProgram.m
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//

#import "XPYGLProgram.h"
#import "XPYGLShader.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>

@implementation XPYGLProgram {
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint program;
}

- (instancetype)init {
    return [self initWithVertexShader:XPYDefaultVertexShader fragmentShader:XPYDefaultFragmentShader];
}

- (instancetype)initWithVertexShader:(NSString *)vertexString fragmentShader:(NSString *)fragmentString {
    self = [super init];
    if (self) {
        [self createProgramWithVertexShader:vertexString fragmentShader:fragmentString];
    }
    return self;
}

- (void)dealloc {
    if (vertexShader != 0) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (fragmentShader != 0) {
        glDeleteShader(fragmentShader);
        fragmentShader = 0;
    }
    if (program != 0) {
        glDeleteProgram(program);
        program = 0;
    }
}

- (void)use {
    if (program == 0) {
        return;
    }
    glUseProgram(program);
}

- (int)attributeLocation:(NSString *)name {
    return glGetAttribLocation(program, [name UTF8String]);
}

- (int)uniformLocation:(NSString *)name {
    return glGetUniformLocation(program, [name UTF8String]);
}

/// 创建 GL 程序，并链接
- (void)createProgramWithVertexShader:(NSString *)vertex fragmentShader:(NSString *)fragment {
    vertexShader = [self loadShader:vertex type:GL_VERTEX_SHADER];
    fragmentShader = [self loadShader:fragment type:GL_FRAGMENT_SHADER];
    if (vertexShader == 0 || fragmentShader == 0) {
        return;
    }
    program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    glLinkProgram(program);
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status != GL_TRUE) {
        glDeleteProgram(program);
        program = 0;
    }
}

/// 创建编译 shader
- (GLuint)loadShader:(NSString *)shaderString type:(GLenum)type {
    GLuint shader = glCreateShader(type);
    const GLchar *source = (GLchar *)[shaderString UTF8String];
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled != GL_TRUE) {
        glDeleteShader(shader);
        shader = 0;
    }
    return shader;
}

@end
