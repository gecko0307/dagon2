#version 460

vec3 sRGB(vec3 v)
{
    return mix(12.92 * v, 1.055 * pow(v, vec3(0.41666)) - 0.055, lessThan(vec3(0.0031308), v));
}

#define COLOR_PROFILE_GAMMA22 0
#define COLOR_PROFILE_SRGB 1
#define COLOR_PROFILE_LINEAR 2
#define COLOR_PROFILE_GAMMA44 3

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    uvec4 flags;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    vec4 inputColor = texture(colorBuffer, texCoords);
    
    vec3 outputColor = inputColor.rgb;
    if (ubo.flags[0] == COLOR_PROFILE_GAMMA22)
        outputColor = pow(outputColor, vec3(1.0 / 2.2));
    else if (ubo.flags[0] == COLOR_PROFILE_SRGB)
        outputColor = sRGB(outputColor);
    else if (ubo.flags[0] == COLOR_PROFILE_GAMMA44)
        outputColor = pow(outputColor, vec3(1.0 / 2.4));
    
    outColor = vec4(outputColor, 1.0);
}
