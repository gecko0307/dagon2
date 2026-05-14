#version 460

layout(location = 0) in vec3 va_position;
layout(location = 1) in vec2 va_texcoords;
layout(location = 2) in vec3 va_normal;

layout(location = 0) out vec3 eyePosition;
layout(location = 1) out vec2 texCoords;

layout(set = 1, binding = 0) uniform UniformBuffer
{
    mat4 modelViewMatrix;
    mat4 normalMatrix;
    mat4 projectionMatrix;
    mat4 prevModelViewMatrix;
} ubo;

void main()
{
    vec4 modelPosHmg = vec4(va_position, 1.0);
    vec4 eyePosHmg = ubo.modelViewMatrix * modelPosHmg;
    eyePosition = eyePosHmg.xyz;
    texCoords = va_texcoords;
    
    gl_Position = ubo.projectionMatrix * eyePosHmg;
    
    // Adapt to Vulkan
    gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
}
