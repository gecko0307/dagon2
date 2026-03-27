#version 460

#define PI 3.14159265359
const float PI2 = PI * 2.0;
const float INVPI = 1.0 / PI;

// Converts normalized device coordinates to eye space position
vec3 unproject(mat4 invProjMatrix, vec3 ndc)
{
    vec4 clipPos = vec4(ndc * 2.0 - 1.0, 1.0);
    vec4 res = invProjMatrix * clipPos;
    return res.xyz / res.w;
}

layout(set = 2, binding = 0) uniform sampler2D depthBuffer;
layout(set = 2, binding = 1) uniform sampler2D roughnessMetallicBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    mat4 invProjectionMatrix;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    vec3 ndc = vec3(texCoords, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePos, 1.0)).xyz;
    
    float shadingMask = texture(roughnessMetallicBuffer, texCoords).a;
    
    const float fogStart = 0.0;
    const float fogEnd = 100.0;
    
    const float fogEnergy = 2.0;
    const float fogDensity = 0.5;
    const vec3 fogColor = vec3(1.0, 1.0, 1.0);
    
    float groundFog = 1.0 - clamp(worldPos.y, 0.0, 1.0);
    groundFog = groundFog * groundFog * fogDensity;
    
    float linearDepth = abs(eyePos.z);
    float atmosphericFog = clamp((linearDepth - fogStart) / (fogEnd - fogStart), 0.0, 1.0);
    //radiance = mix(toLinear(fogColor.rgb), radiance, fogFactor);
    
    outColor = vec4(fogColor, shadingMask * clamp(groundFog + atmosphericFog, 0.0, 1.0));
}
