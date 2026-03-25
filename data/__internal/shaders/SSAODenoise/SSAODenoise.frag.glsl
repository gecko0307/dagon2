#version 460

layout(set = 2, binding = 0) uniform sampler2D occlusionBuffer;
layout(set = 2, binding = 1) uniform sampler2D depthBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
    vec4 fparams;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

float factor = ubo.fparams[0];
const int radius = 2;
const bool depthAware = true;

float bilateral()
{
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    float centerAO = texelFetch(occlusionBuffer, pixelCoord, 0).r;
    float centerDepth = texelFetch(depthBuffer, pixelCoord, 0).r;
    
    float res = 0.0;
    float total = 0.0;
    
    for (int x = -radius; x <= radius; x += 1)
    {
        for (int y = -radius; y <= radius; y += 1)
        {
            ivec2 offset = ivec2(x, y);
            float sampleAO = texelFetch(occlusionBuffer, pixelCoord + offset, 0).r;
            float weight;
            if (depthAware)
            {
                float sampleDepth = texelFetch(depthBuffer, pixelCoord + offset, 0).r;
                float depthDiff = abs(sampleDepth - centerDepth);
                weight = max(0.0, 1.0 - pow(depthDiff, 0.1));
            }
            else
            {
                weight = max(0.0, 1.0 - abs(sampleAO - centerAO) * 0.25);
            }
            res += sampleAO * weight;
            total += weight;
       }
    }
    
    return mix(centerAO, res / max(total, 0.0001), factor);
}

void main()
{
    float res = bilateral();
    outColor = vec4(vec3(res), 1.0); 
}
