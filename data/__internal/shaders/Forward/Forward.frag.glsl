#version 460

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    vec4 baseColor;
    vec4 emission;
    vec4 brdf;
    vec4 materialOptions;
    vec4 ambientColor;
    uvec4 flags;
    vec4 resolution;
} ubo;

layout(location = 0) in vec3 eyePosition;
layout(location = 1) in vec2 texCoords;
layout(location = 2) in vec3 eyeNormal;
layout(location = 3) in vec3 modelPosition;
layout(location = 4) in vec4 currPosition;
layout(location = 5) in vec4 prevPosition;

// Indices in ubo.brdf
#define BRDF_ROUGHNESS 0
#define BRDF_METALLIC 1
#define BRDF_F0 2
#define BRDF_SSS 3

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

// Bit masks for FLAGS_OUTPUT flag
#define OUTFLAG_DEPTH 1 << 0

// Bit masks for FLAGS_ENTITY flag
#define ENTFLAG_STATIC 1 << 0
#define ENTFLAG_SHADED 1 << 1

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outVelocity;

out float gl_FragDepth;

void main()
{
    vec2 gbufTexCoords = gl_FragCoord.xy / ubo.resolution.xy;
    
    vec3 N = normalize(eyeNormal);
    vec3 E = normalize(-eyePosition);
    
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePosition, 1.0)).xyz;
    vec3 worldCamPos = (ubo.invViewMatrix[3]).xyz;
    vec3 wE = normalize(worldPos - worldCamPos);
    vec3 wN = normalize((ubo.invViewMatrix * vec4(N, 0.0)).xyz);
    vec3 wR = reflect(wE, wN);
    
    vec4 baseColor = ubo.baseColor;
    
    float shadedMask = float(ubo.flags[FLAGS_ENTITY] & ENTFLAG_SHADED);
    float motionBlurMask = ubo.materialOptions[OPT_MOTION_BLUR_MASK];
    
    float alpha = baseColor.a * ubo.materialOptions[OPT_ALPHA];
    
    vec3 outputColor = toLinear(baseColor.rgb);
    
    // Screen-space velocity
    vec2 posScreen = (currPosition.xy / currPosition.w) * 0.5 + 0.5;
    posScreen.y = 1.0 - posScreen.y; // Adapt to Vulkan
    vec2 prevPosScreen = (prevPosition.xy / prevPosition.w) * 0.5 + 0.5;
    prevPosScreen.y = 1.0 - prevPosScreen.y; // Adapt to Vulkan
    vec2 velocity = posScreen - prevPosScreen;
    
    float staticMask = float(ubo.flags[FLAGS_ENTITY] & ENTFLAG_STATIC);
    
    outColor = vec4(outputColor, alpha);
    outVelocity = vec4(velocity, motionBlurMask, staticMask);
    
    gl_FragDepth = gl_FragCoord.z;
}
