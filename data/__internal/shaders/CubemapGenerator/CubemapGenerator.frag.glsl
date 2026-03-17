#version 460

#define PI 3.14159265359
const float PI2 = PI * 2.0;

vec2 envMapEquirect(vec3 dir)
{
    float u = 1.0 - (atan(dir.x, dir.z) / PI2 + 0.5);
    float v = acos(dir.y) / PI;
    return vec2(u, v);
}

layout(set = 2, binding = 0) uniform sampler2D envmap;
layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 pixelToWorldMatrix;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 fragColor;

void main()
{
    vec2 ndc = vec2(texCoords.x, 1.0 - texCoords.y) * 2.0 - 1.0;
    vec3 ray = normalize(vec3(ndc, 1.0f));
    vec3 rayWorld = (ubo.pixelToWorldMatrix * vec4(ray, 0.0f)).xyz;
    vec2 sampleTexCoord = envMapEquirect(rayWorld);
    fragColor = texture(envmap, sampleTexCoord);
}
