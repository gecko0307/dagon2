#version 460

float hash(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D velocityBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
    vec4 fparams1; // time, offsetRandomCoef, minDistance, maxDistance
    vec4 fparams2; // blurScale, radialBlur
    uvec4 iparams; // samples
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

float blurScale = ubo.fparams2.x;
uint samples = ubo.iparams.x;
float offsetRandomCoef = ubo.fparams1.y;
float time = ubo.fparams1.x;
float minDistance = ubo.fparams1.z;
float maxDistance = ubo.fparams1.w;
float radialBlur = ubo.fparams2.y;

void main()
{
    vec3 original = texture(colorBuffer, texCoords).rgb;
    vec3 velocity = texture(velocityBuffer, texCoords).rgb;
    float writeMask = velocity.z;
    vec3 res = original;
    
    vec2 radialBlurVec = (texCoords - vec2(0.5, 0.5));
    
    vec2 blurVec = velocity.xy;
    float len = length(blurVec);
    
    float blurVecLen = clamp(len - minDistance, 0.0, maxDistance) / (maxDistance - minDistance) * blurScale;
    blurVec = normalize(blurVec) * blurVecLen + radialBlurVec * radialBlur;
    
    float speed = length(blurVec * ubo.resolution.xy);
    uint nSamples = clamp(uint(speed), 1, samples);
    float invSamplesMinusOne = 1.0 / max(float(nSamples) - 1.0, 1.0);
    float usedSamples = 1.0;
    float rnd = mix(0.5, hash(texCoords * 467.759 + time), offsetRandomCoef);

    for (uint i = 1; i < nSamples; i++)
    {
        vec2 uvSample = texCoords + blurVec * (float(i) * invSamplesMinusOne - rnd);
        vec4 velocitySample = texture(velocityBuffer, uvSample);
        float mask = velocitySample.z;
        res += texture(colorBuffer, uvSample).rgb * mask;
        usedSamples += mask;
    }

    res = max(res, vec3(0.0));
    res = res / max(usedSamples, 1.0);

    outColor = vec4(mix(original, res, writeMask), 1.0);
}
