#version 460

layout(location = 0) in vec2 texCoords;

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 baseColor;
    vec4 alphaOptions;
    uvec4 flags;
} ubo;

#define FLAGS_TEXTURE 0

#define TEXFLAG_HAS_BASECOLOR_TEXTURE 1 << 0

layout(location = 0) out vec4 outColor;

void main()
{    
    vec4 baseColor = ubo.baseColor;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BASECOLOR_TEXTURE) != 0)
        baseColor *= texture(baseColorTexture, texCoords);
    
    float alpha = baseColor.a * ubo.alphaOptions.a;
    if (alpha < ubo.alphaOptions.x)
        discard;
    
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
