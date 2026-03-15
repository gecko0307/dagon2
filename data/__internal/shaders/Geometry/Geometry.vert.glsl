#version 460

layout(location = 0) in vec3 va_position;
layout(location = 1) in vec2 va_texcoords;
layout(location = 2) in vec3 va_normal;

layout(location = 0) out vec3 eyePosition;
layout(location = 1) out vec2 texCoords;
layout(location = 2) out vec3 eyeNormal;
layout(location = 3) out vec3 modelPosition;

layout(set = 1, binding = 0) uniform UniformBuffer
{
    mat4 modelViewMatrix;
    mat4 normalMatrix;
    mat4 projectionMatrix;
} ubo;

void main()
{
    vec4 eyePosHmg = ubo.modelViewMatrix * vec4(va_position, 1.0);
    eyePosition = eyePosHmg.xyz;
    texCoords = va_texcoords;
    eyeNormal = (ubo.normalMatrix * vec4(va_normal, 0.0)).xyz;
    modelPosition = va_position;
    gl_Position = ubo.projectionMatrix * eyePosHmg;
}
