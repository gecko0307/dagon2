#version 460

layout(location = 0) in vec2 texCoords;

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 baseColor;
    vec4 materialOptions;
    uvec4 flags;
} ubo;

// Indices in ubo.materialOptions
#define OPT_ALPHA 0
#define OPT_ALPHA_CLIP_THRESHOLD 1
#define OPT_MOTION_BLUR_MASK 2
#define OPT_SKYBOX_MIP_LEVEL 3

// Indices in ubo.flags
#define FLAGS_TEXTURE 0
#define FLAGS_OUTPUT 1
#define FLAGS_ENTITY 2
#define FLAGS_MISC 3

// Bit masks for FLAGS_TEXTURE flag
#define TEXFLAG_HAS_BASECOLOR_TEXTURE 1 << 0
#define TEXFLAG_HAS_NORMAL_TEXTURE 1 << 1
#define TEXFLAG_HAS_HEIGHT_TEXTURE 1 << 2
#define TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE 1 << 3
#define TEXFLAG_HAS_EMISSION_TEXTURE 1 << 4
#define TEXFLAG_HAS_SKYBOX_TEXTURE 1 << 5
#define TEXFLAG_HAS_AMBIENT_TEXTURE 1 << 6

layout(location = 0) out vec4 outColor;

void main()
{    
    vec4 baseColor = ubo.baseColor;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BASECOLOR_TEXTURE) != 0)
        baseColor *= texture(baseColorTexture, texCoords);
    
    float alpha = baseColor.a * ubo.materialOptions[OPT_ALPHA];
    if (alpha < ubo.materialOptions[OPT_ALPHA_CLIP_THRESHOLD])
        discard;
    
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
