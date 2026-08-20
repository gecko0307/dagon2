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

// Permuted congruential generator
uint pcg(uint x)
{
    uint state = x * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float hash2(uvec2 v)
{
    return pcg(v.x ^ (v.y * 1103515245u));
}

float hash3(uvec3 v)
{
    return pcg(v.x ^ (v.y * 1103515245u) ^ (v.z * 134775813u));
}

float hash(vec2 uv)
{
    uvec2 ip = uvec2(floatBitsToUint(uv.x), floatBitsToUint(uv.y));
    return float(hash2(ip)) / float(0xFFFFFFFFu);
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
    vec2 uv2 = tcoord + uv;
    float depth = texture(depthBuffer, uv2).x;
    vec3 ndc = vec3(uv2, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 pos = unproject(ubo.invProjectionMatrix, ndc);
    vec3 diff = pos - p;
    float l = length(diff);
    vec3 v = diff / l;
    float d = l * SSAO_SCALE;
    float ao = max(0.0, dot(cnorm, v) - SSAO_BIAS) * (1.0 / (1.0 + d));
    return ao;
}

#define GOLDEN_ANGLE 2.4
const float cosGA = cos(GOLDEN_ANGLE); // 0.73739
const float sinGA = sin(GOLDEN_ANGLE); // 0.67546

float spiralSSAO(vec2 uv, vec3 p, vec3 n, float rad)
{
    float ao = 0.0;
    float invSamples = 1.0 / float(ssaoSamples);
    float radius = 0.0;
    float rStep = invSamples * rad;

    float rotatePhase = hash(uv * 467.759) * 6.28 + ubo.fparams[FPARAM_TIME];
    
    vec2 dir = vec2(sin(rotatePhase), cos(rotatePhase));

    for (int i = 0; i < ssaoSamples; i++)
    {
        radius += rStep;
        ao += ssao(uv, dir * radius, p, n);
        dir = vec2(
            dir.x * cosGA - dir.y * sinGA,
            dir.x * sinGA + dir.y * cosGA
        );
    }

    ao *= invSamples;
    return (1.0 - ao);
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
    float depthFactor = clamp(-eyePos.z / 100.0, 0.0, 1.0);
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb * 2.0 - 1.0);

    float occlusion = spiralSSAO(texCoords, eyePos, N, ssaoRadius / -eyePos.z);
    occlusion = pow(clamp(occlusion, 0.0, 1.0), ssaoPower);
    occlusion = mix(occlusion, 1.0, depthFactor);
    
    // Temporal accumulation
    if (ubo.iparams[IPARAM_TEMPORAL_ACCUMULATION] == 1)
    {
        vec2 uvVelocity = texture(velocityBuffer, texCoords).xy;
        float prevOcclusion = texture(prevOcclusionBuffer, texCoords - uvVelocity).x;
        float velocityLength = length(uvVelocity);
        float alpha = mix(0.05, 1.0, clamp(velocityLength * 200.0, 0.0, 1.0));
        occlusion = mix(prevOcclusion, occlusion, alpha);
    }
    
    outColor = vec4(vec3(occlusion), 0.0);
}
