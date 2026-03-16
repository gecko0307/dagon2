#version 460

vec3 toGamma(vec3 v)
{
    return pow(v, vec3(1.0 / 2.2));
}

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    vec4 inputColor = texture(colorBuffer, texCoords);
    outColor = vec4(toGamma(inputColor.rgb), 1.0);
}
