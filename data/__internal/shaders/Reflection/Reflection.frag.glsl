#version 460

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D reflectionBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    vec3 original = texture(colorBuffer, texCoords).rgb;
    vec4 reflection = texture(reflectionBuffer, texCoords);
    vec3 color = mix(original, reflection.rgb, reflection.a);
    outColor = vec4(color, 1.0);
}
