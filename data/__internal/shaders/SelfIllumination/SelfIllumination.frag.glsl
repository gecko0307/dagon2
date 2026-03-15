#version 460

layout(set = 2, binding = 0) uniform sampler2D emissionBuffer;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    vec3 emission = texture(emissionBuffer, texCoords).rgb;
    outColor = vec4(emission, 1.0f);
}
