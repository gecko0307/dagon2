#version 460

layout(set = 2, binding = 0) uniform sampler2D occlusionBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

const float radius = 2.0;
const float spatialSigma = 0.7;
const float rangeSigma = 0.7;
const float factor = 1.0;

float bilateral()
{
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    float centerAO = texelFetch(occlusionBuffer, pixelCoord, 0).r;
    
    float res = 0.0;
    float total = 0.0;
    
    for (float x = -radius; x <= radius; x += 1.0)
    {
        for (float y = -radius; y <= radius; y += 1.0)
        {
            float sampleAO = texelFetch(occlusionBuffer, pixelCoord + ivec2(x, y), 0).r;
            
            float spatialDistSq = float(x * x + y * y);
            float spatialWeight = exp(-0.5 * spatialDistSq / (spatialSigma * spatialSigma));
            
            float rDiff = abs(sampleAO - centerAO);
            float rangeWeight = exp(-0.5 * (rDiff * rDiff) / (rangeSigma * rangeSigma));
            
            float weight = spatialWeight * rangeWeight;
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
