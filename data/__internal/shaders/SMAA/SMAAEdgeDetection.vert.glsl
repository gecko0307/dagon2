#version 460

/*
 * Subpixel Morphological Anti-Aliasing (edge detection pass).
 * SMAA implementation is based on the code by Jorge Jimenez,
 * Jose I. Echevarria, Belen Masia, Fernando Navarro and Diego Gutierrez.
 * https://github.com/iryoku/smaa
 * See license/SMAA.txt for details.
 */

layout(location = 0) in vec2 va_position;
layout(location = 1) in vec2 va_texcoords;

layout(location = 0) out vec2 texCoords;
layout(location = 1) out vec4 offset[3];

layout(set = 1, binding = 0) uniform UniformBuffer
{
    vec4 invResolution; // [1.0 / viewWidth, 1.0 / viewHeight, 0.0, 0.0]
} ubo;

void smaaEdgeDetect(vec2 texcoord, out vec4 offset[3])
{
    offset[0] = fma(ubo.invResolution.xyxy, vec4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy); //-1.0
    offset[1] = fma(ubo.invResolution.xyxy, vec4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy); // 0.0
    offset[2] = fma(ubo.invResolution.xyxy, vec4(-2.0, 0.0, 0.0, -2.0), texcoord.xyxy); //-2.0
}

void main()
{
    texCoords = va_texcoords;
    smaaEdgeDetect(va_texcoords, offset);
    
    vec2 clipVertex = va_position * 2.0 - 1.0;
    clipVertex.y = -clipVertex.y;
    gl_Position = vec4(clipVertex, 0.0, 1.0);
}
