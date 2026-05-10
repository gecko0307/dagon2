#version 460

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D reflectionBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

vec3 blurReflection(vec2 uv)
{
    vec2 texel = 1.0 / ubo.resolution.xy;
    vec3 sum = texture(reflectionBuffer, uv).rgb * 0.4;
    sum += texture(reflectionBuffer, uv + vec2(texel.x, 0.0)).rgb * 0.15;
    sum += texture(reflectionBuffer, uv - vec2(texel.x, 0.0)).rgb * 0.15;
    sum += texture(reflectionBuffer, uv + vec2(0.0, texel.y)).rgb * 0.15;
    sum += texture(reflectionBuffer, uv - vec2(0.0, texel.y)).rgb * 0.15;
    return sum;
}

void main()
{
    vec3 original = texture(colorBuffer, texCoords).rgb;
    vec4 reflection = texture(reflectionBuffer, texCoords);
    vec3 blurredReflection = blurReflection(texCoords);
    vec3 color = mix(original, blurredReflection, reflection.a);
    outColor = vec4(color, 1.0);
}
