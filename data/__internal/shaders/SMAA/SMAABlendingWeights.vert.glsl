#version 460

/*
 * SMAA implementation is based on code by Jorge Jimenez, Jose I. Echevarria,
 * Belen Masia, Fernando Navarro and Diego Gutierrez.
 */

#define SMAA_MAX_SEARCH_STEPS 8

layout(location = 0) in vec2 va_position;
layout(location = 1) in vec2 va_texcoords;

layout(location = 0) out vec2 texCoords;
layout(location = 1) out vec2 pixCoords;
layout(location = 2) out vec4 offset[3];

layout(set = 1, binding = 0) uniform UniformBuffer
{
    vec4 resolution; // [1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight]
} ubo;

void main()
{
    texCoords = va_texcoords;
    pixCoords = va_texcoords * ubo.resolution.zw;
    
    offset[0] = fma(ubo.resolution.xyxy, vec4(-0.25, -0.125,  1.25, -0.125), va_texcoords.xyxy);
    offset[1] = fma(ubo.resolution.xyxy, vec4(-0.125, -0.25, -0.125,  1.25), va_texcoords.xyxy);
    offset[2] = fma(ubo.resolution.xxyy, vec4(-2.0, 2.0, -2.0, 2.0) * float(SMAA_MAX_SEARCH_STEPS), vec4(offset[0].xz, offset[1].yw));
    
    vec2 clipVertex = va_position * 2.0 - 1.0;
    clipVertex.y = -clipVertex.y;
    gl_Position = vec4(clipVertex, 0.0, 1.0);
}
