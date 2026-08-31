#version 460

/*
 * Subpixel Morphological Anti-Aliasing (neighborhood blending pass).
 * Implementation is based on the code by Jorge Jimenez,
 * Jose I. Echevarria, Belen Masia, Fernando Navarro and Diego Gutierrez.
 * https://github.com/iryoku/smaa
 * See license/SMAA.txt for details.
 */

layout(location = 0) in vec2 va_position;
layout(location = 1) in vec2 va_texcoords;

layout(location = 0) out vec2 texCoords;
layout(location = 1) out vec4 offset[2];

layout(set = 1, binding = 0) uniform UniformBuffer
{
    vec4 resolution; // [1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight]
} ubo;

void main()
{
    texCoords = va_texcoords;
    
    offset[0] = va_texcoords.xyxy + ubo.resolution.xyxy * vec4(-1.0, 0.0, 0.0, -1.0);
    offset[1] = va_texcoords.xyxy + ubo.resolution.xyxy * vec4( 1.0, 0.0, 0.0,  1.0);
    
    vec2 clipVertex = va_position * 2.0 - 1.0;
    clipVertex.y = -clipVertex.y;
    gl_Position = vec4(clipVertex, 0.0, 1.0);
}
