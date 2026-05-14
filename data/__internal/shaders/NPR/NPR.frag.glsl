#version 460

layout(location = 0) in vec3 eyePosition;
layout(location = 1) in vec2 texCoords;

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
layout(set = 2, binding = 1) uniform sampler2D velocityBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
    vec4 baseColor;
    uvec4 iparams;
} ubo;

layout(location = 0) out vec4 outColor;

void main()
{
    vec2 gbufTexCoord = gl_FragCoord.xy / ubo.resolution.xy;
    
    bool isStaticSurface = texture(velocityBuffer, gbufTexCoord).a > 0.0;
    if (!isStaticSurface)
        discard;
    
    vec4 baseColor = ubo.baseColor;
    if (ubo.iparams[0] != 0)
    {
        baseColor *= texture(baseColorTexture, texCoords);
    }
    
    outColor = baseColor;
}
