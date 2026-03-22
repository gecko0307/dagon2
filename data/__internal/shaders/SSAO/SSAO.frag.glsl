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

float hash(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

layout(set = 2, binding = 0) uniform sampler2D depthBuffer;
layout(set = 2, binding = 1) uniform sampler2D normalBuffer;
layout(set = 2, binding = 2) uniform sampler2D prevOcclusionBuffer;
layout(set = 2, binding = 3) uniform sampler2D velocityBuffer;

#define FPARAM_TIME 0
#define FPARAM_RADIUS 1
#define FPARAM_POWER 2
#define IPARAM_NUM_SAMPLES 0
#define IPARAM_TEMPORAL_ACCUMULATION 1

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    mat4 invViewMatrix;
    mat4 invProjectionMatrix;
    vec4 resolution;
    vec4 fparams;
    uvec4 iparams;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

// SSAO implementation based on code by Reinder Nijhoff
// https://www.shadertoy.com/view/Ms33WB

uint ssaoSamples = ubo.iparams[IPARAM_NUM_SAMPLES];
float ssaoRadius = ubo.fparams[FPARAM_RADIUS];
float ssaoPower = ubo.fparams[FPARAM_POWER];

#define SSAO_SCALE 1.0
#define SSAO_BIAS 0.01

float ssao(in vec2 tcoord, in vec2 uv, in vec3 p, in vec3 cnorm)
{
    float depth = texture(depthBuffer, tcoord + uv).x;
    vec3 ndc = vec3(tcoord + uv, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 pos = unproject(ubo.invProjectionMatrix, ndc);
    vec3 diff = pos - p;
    float l = length(diff);
    vec3 v = diff / l;
    float d = l * SSAO_SCALE;
    float ao = max(0.0, dot(cnorm, v) - SSAO_BIAS) * (1.0 / (1.0 + d));
    return ao;
}

float spiralSSAO(vec2 uv, vec3 p, vec3 n, float rad)
{
    const float goldenAngle = 2.4;
    float ao = 0.0;
    float invSamples = 1.0 / float(ssaoSamples);
    float radius = 0.0;

    float rotatePhase = hash(uv * 467.759) * 6.28 + ubo.fparams[FPARAM_TIME];
    float rStep = invSamples * rad;
    vec2 spiralUV;

    for (int i = 0; i < ssaoSamples; i++)
    {
        spiralUV.x = sin(rotatePhase);
        spiralUV.y = cos(rotatePhase);
        radius += rStep;
        ao += ssao(uv, spiralUV * radius, p, n);
        rotatePhase += goldenAngle;
    }
    
    ao *= invSamples;
    
    return ao;
}

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    
    if (depth == 1.0)
    {
        outColor = vec4(1.0, 1.0, 1.0, 0.0);
        return;
    }
    
    vec3 ndc = vec3(texCoords, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb);

    float occlusion = spiralSSAO(texCoords, eyePos, N, ssaoRadius / -eyePos.z);
    occlusion = pow(clamp(1.0 - occlusion, 0.0, 1.0), ssaoPower);
    occlusion = mix(occlusion, 1.0, clamp(-eyePos.z / 100.0, 0.0, 1.0));
    
    // Temporal accumulation
    if (ubo.iparams[IPARAM_TEMPORAL_ACCUMULATION] == 1)
    {
        vec2 uvVelocity = texture(velocityBuffer, texCoords).xy;
        float prevOcclusion = texture(prevOcclusionBuffer, texCoords - uvVelocity).x;
        float velocityLength = length(uvVelocity);
        float alpha = mix(0.01, 1.0, clamp(velocityLength * 80.0, 0.0, 1.0));
        occlusion = mix(prevOcclusion, occlusion, alpha);
    }
    
    outColor = vec4(vec3(occlusion), 0.0);
}
