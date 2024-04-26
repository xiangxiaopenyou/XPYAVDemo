//
//  XPYGLShader.m
//  XPYAVKit
//
//  Created by MoMo on 2024/4/3.
//

#import "XPYGLShader.h"

#define SHADER_STRING(text) @#text

NSString * const XPYSimpleVertexShader =  SHADER_STRING
(
     attribute vec4 v_position;
     attribute vec4 v_color;
     
     varying mediump vec4 f_color;
     
     void main()
     {
        f_color = v_color;
        gl_Position = v_position;
     }
);

NSString * const XPYSimpleFragmentShader = SHADER_STRING
(
    varying mediump vec4 f_color;
    
    void main()
    {
        gl_FragColor = f_color;
    }
);

NSString * const XPYDefaultVertexShader =  SHADER_STRING
(
     attribute vec4 position;    // 通过 attribute 通道获取顶点信息
     attribute vec4 inputTextureCoordinate;  // 通过 attribute 通道获取纹理坐标信息
     
     varying vec2 textureCoodinate;  // 顶点着色器和片段着色器之间传递纹理坐标
     uniform mat4 mvpMatrix; // 通过 uniform 通道获取 mvp 矩阵信息
     
     void main()
     {
         gl_Position = mvpMatrix * position; // 计算最终位置
         textureCoodinate = inputTextureCoordinate.xy;   // 纹理坐标信息的 xy 分量传给片段着色器
     }
);

NSString * const XPYDefaultFragmentShader = SHADER_STRING
(
    varying highp vec2 textureCoodinate;   // 从顶点着色器传递过来的纹理坐标
    uniform sampler2D inputImageTexture;   // 通过 uniform 通道获取纹理信息
    
    void main()
    {
        gl_FragColor = texture2D(inputImageTexture, textureCoodinate);  // 获取纹理对应坐标的颜色值作为最终要用的颜色信息
    }
);
