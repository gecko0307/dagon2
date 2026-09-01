#version 460

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D reflectionBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
    ivec4 iparams;
} ubo;

#define invResolution ubo.resolution.zw
#define blurEnabled bool(ubo.iparams.x)
#define blurRadius ubo.iparams.y

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

vec4 blurReflection()
{
    vec4 sum = vec4(0.0);
    int count = 0;
    
    for (int x = -blurRadius; x <= blurRadius; x++)
    {
        for (int y = -blurRadius; y <= blurRadius; y++)
        {
            vec2 offset = vec2(float(x), float(y)) * invResolution;
            sum += texture(reflectionBuffer, texCoords + offset);
            count++;
        }
    }
    
    return sum / float(count);
}

void main()
{
    vec3 original = texture(colorBuffer, texCoords).rgb;
    vec4 reflection = blurEnabled?
        blurReflection() :
        texture(reflectionBuffer, texCoords);
    vec3 color = mix(original, reflection.rgb, reflection.a);
    outColor = vec4(color, 1.0);
}
