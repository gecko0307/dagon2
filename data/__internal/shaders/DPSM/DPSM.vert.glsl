#version 460

layout(location = 0) in vec3 va_position;
layout(location = 1) in vec2 va_texcoords;
layout(location = 2) in vec3 va_normal;

layout(std140, set = 1, binding = 0) uniform UniformBuffer
{
    mat4 modelMatrix;
    vec4 lightPosition;
    vec4 lightParams;
} ubo;

layout(location = 0) out vec2 texCoords;
layout(location = 1) out float clipZ;
layout(location = 2) out float z;

void main()
{
    vec4 modelPosHmg = vec4(va_position, 1.0);
    texCoords = va_texcoords; //(ubo.textureMatrix * vec3(va_texcoords, 1.0)).xy;
    
    vec4 worldPos = ubo.modelMatrix * modelPosHmg;
    vec3 lightSpacePos = worldPos.xyz - ubo.lightPosition.xyz;
    float distanceToLight = length(lightSpacePos);
    vec3 dir = normalize(lightSpacePos);
    clipZ = dir.z;
    dir.z *= ubo.lightParams.y; // half-space direction
    vec2 xy = dir.xy / (1.0 + dir.z);
    z = distanceToLight / ubo.lightParams.x;
    gl_Position = vec4(xy, 2.0 * z - 1.0, 1.0);
    
    // Adapt to Vulkan
    gl_Position.z = (gl_Position.z + gl_Position.w) * 0.5;
}
