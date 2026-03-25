#version 460

layout(location = 0) in vec3 va_position;
layout(location = 1) in vec2 va_texcoords;
layout(location = 2) in vec3 va_normal;

layout(set = 1, binding = 0) uniform UniformBuffer
{
    mat4 modelViewMatrix;
    mat4 projectionMatrix;
} ubo;

layout(location = 0) out vec2 texCoords;

void main()
{
    vec4 modelPosHmg = vec4(va_position, 1.0);
    texCoords = va_texcoords; //(ubo.textureMatrix * vec3(va_Texcoord, 1.0)).xy;
    gl_Position = ubo.projectionMatrix * (ubo.modelViewMatrix * modelPosHmg);
    
    // Adapt to Vulkan
    gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
}
