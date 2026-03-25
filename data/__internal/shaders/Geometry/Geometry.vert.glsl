#version 460

layout(location = 0) in vec3 va_position;
layout(location = 1) in vec2 va_texcoords;
layout(location = 2) in vec3 va_normal;

layout(location = 0) out vec3 eyePosition;
layout(location = 1) out vec2 texCoords;
layout(location = 2) out vec3 eyeNormal;
layout(location = 3) out vec3 modelPosition;
layout(location = 4) out vec4 currPosition;
layout(location = 5) out vec4 prevPosition;

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
    eyeNormal = (ubo.normalMatrix * vec4(va_normal, 0.0)).xyz;
    modelPosition = va_position;
    
    currPosition = ubo.projectionMatrix * eyePosHmg;
    prevPosition = ubo.projectionMatrix * (ubo.prevModelViewMatrix * modelPosHmg);
    
    gl_Position = currPosition;
    gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
}
