#version 460

layout(location = 0) in vec3 va_position;
layout(location = 1) in vec2 va_texcoords;
layout(location = 2) in vec3 va_normal;

layout(set = 1, binding = 0) uniform UniformBuffer
{
    mat4 modelViewMatrix;
    mat4 normalMatrix;
    mat4 projectionMatrix;
} ubo;

void main()
{
    gl_Position = ubo.projectionMatrix * ubo.modelViewMatrix * vec4(va_position, 1.0);
    
    // Adapt to Vulkan
    gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
}
