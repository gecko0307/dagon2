#version 460

/*
 * Based on the method by Christian Schüler:
 * http://www.thetenthplanet.de/archives/1180
 */
mat3 cotangentFrame(in vec3 N, in vec3 p, in vec2 uv)
{
    vec3 dp1 = dFdx(p);
    vec3 dp2 = -dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = -dFdy(uv);

    vec3 dp2perp = cross(dp2, N);
    vec3 dp1perp = cross(N, dp1);
    
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;
    
    float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
    return mat3(T * invmax, B * invmax, N);
}

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

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

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
layout(set = 2, binding = 1) uniform sampler2D normalTexture;
layout(set = 2, binding = 2) uniform sampler2D heightTexture;
layout(set = 2, binding = 3) uniform sampler2D roughnessMetallicTexture;
layout(set = 2, binding = 4) uniform sampler2D emissionTexture;
layout(set = 2, binding = 5) uniform samplerCube skyboxTexture;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    vec4 baseColor;
    vec4 emission;
    vec4 brdf;
    vec4 materialOptions;
    uvec4 flags;
    vec4 resolution;
} ubo;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outRoughnessMetallic;
layout(location = 3) out vec4 outEmission;
layout(location = 4) out vec4 outVelocity;

out float gl_FragDepth;

const float tanNormalYFactor = -1.0;

const float parallaxScale = 0.03;
const float parallaxBias = -0.01;

void main()
{
    vec2 uv = texCoords;
    vec3 E = normalize(-eyePosition);
    vec3 N = normalize(eyeNormal);
    
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_NORMAL_TEXTURE) != 0)
    {
        mat3 tangentToEye = cotangentFrame(N, eyePosition, uv);
        
        if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_HEIGHT_TEXTURE) != 0)
        {
            // Parallax mapping
            vec3 tanE = normalize(E * tangentToEye);
            float height = texture(heightTexture, texCoords).r;
            uv += tanE.xy * (height * parallaxScale + parallaxBias);
        }
        
        vec3 tanN = normalize(texture(normalTexture, uv).rgb * 2.0 - 1.0);
        tanN.y *= tanNormalYFactor;
        N = normalize(tangentToEye * tanN);
    }
    
    vec3 wN = N * mat3(ubo.viewMatrix);
    
    float shadedMask = float((ubo.flags[FLAGS_ENTITY] & ENTFLAG_SHADED) != 0);
    float motionBlurMask = ubo.materialOptions[OPT_MOTION_BLUR_MASK];
    
    vec4 baseColor = ubo.baseColor;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BASECOLOR_TEXTURE) != 0)
        baseColor *= texture(baseColorTexture, uv);
    
    float f0 = ubo.brdf[BRDF_F0];
    
    vec4 roughnessMetallic = vec4(0.0, ubo.brdf.xy, 0.0);
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE) != 0)
        roughnessMetallic = texture(roughnessMetallicTexture, uv);
    float roughness = max(roughnessMetallic.g, 0.001);
    float metallic = roughnessMetallic.b;
    
    vec3 emission = ubo.emission.rgb;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SKYBOX_TEXTURE) != 0)
        emission *= textureLod(skyboxTexture, -normalize(modelPosition), ubo.materialOptions[OPT_SKYBOX_MIP_LEVEL]).rgb;
    else
    {
        if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_EMISSION_TEXTURE) != 0)
            emission *= toLinear(texture(emissionTexture, uv).rgb);
        emission += toLinear(baseColor.rgb) * (1.0 - shadedMask);
    }
    
    float alpha = baseColor.a * ubo.materialOptions[OPT_ALPHA];
    if (alpha < ubo.materialOptions[OPT_ALPHA_CLIP_THRESHOLD]) // Alpha clipping
        discard;
    
    // Screen-space velocity
    vec2 posScreen = (currPosition.xy / currPosition.w) * 0.5 + 0.5;
    posScreen.y = 1.0 - posScreen.y; // Adapt to Vulkan
    vec2 prevPosScreen = (prevPosition.xy / prevPosition.w) * 0.5 + 0.5;
    prevPosScreen.y = 1.0 - prevPosScreen.y; // Adapt to Vulkan
    vec2 velocity = posScreen - prevPosScreen;
    
    float staticMask = float(ubo.flags[FLAGS_ENTITY] & ENTFLAG_STATIC);
    
    float sss = ubo.brdf[BRDF_SSS];
    
    outColor = vec4(baseColor.rgb, sss);
    outNormal = vec4(wN * 0.5 + 0.5, 1.0); // fit the normal to 0..1
    outRoughnessMetallic = vec4(f0, roughness, metallic, shadedMask);
    outEmission = vec4(emission, 1.0);
    outVelocity = vec4(velocity, motionBlurMask, staticMask);
    
    if ((ubo.flags[FLAGS_OUTPUT] & OUTFLAG_DEPTH) != 0)
        gl_FragDepth = gl_FragCoord.z;
    else
        gl_FragDepth = 1.0;
}
