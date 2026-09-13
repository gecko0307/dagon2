#version 460

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

float interleavedGradientNoise(vec2 uv)
{
    float dotResult = dot(uv, vec2(0.06711056, 0.00583715));
    return fract(52.9829189 * fract(dotResult));
}

float bayer4x4(vec2 screenPos)
{
    int x = int(mod(screenPos.x, 4.0));
    int y = int(mod(screenPos.y, 4.0));
    
    int index = x + y * 4;
    float bayer[16] = float[16](
         0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
        12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
         3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
        15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
    );
    
    return bayer[index];
}

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
layout(set = 2, binding = 1) uniform sampler2D normalTexture;
layout(set = 2, binding = 2) uniform samplerCube irradianceTexture;

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
    vec4 lighVector;
} ubo;

layout(location = 0) in vec3 eyePosition;
layout(location = 1) in vec2 texCoords;
layout(location = 2) in vec3 eyeNormal;
layout(location = 3) in vec3 eyeTangent;
layout(location = 4) in vec3 eyeBitangent;
layout(location = 5) in vec3 modelPosition;
layout(location = 6) in vec4 currPosition;
layout(location = 7) in vec4 prevPosition;

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

// Parameter access macros
#define hasBaseColorTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BASECOLOR_TEXTURE) != 0)
#define hasRoughnessMetallicTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE) != 0)
#define hasNormalTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_NORMAL_TEXTURE) != 0)
#define hasHeightTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_HEIGHT_TEXTURE) != 0)
#define hasEmissionTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_EMISSION_TEXTURE) != 0)
#define hasSkyboxTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SKYBOX_TEXTURE) != 0)
#define hasAmbientTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_AMBIENT_TEXTURE) != 0)
#define hasSSSTexture ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SSS_TEXTURE) != 0)
#define isShaded ((ubo.flags[FLAGS_ENTITY] & ENTFLAG_SHADED) != 0)
#define isStatic ((ubo.flags[FLAGS_ENTITY] & ENTFLAG_STATIC) != 0)
#define matAlpha ubo.materialOptions[OPT_ALPHA]
#define matAlphaClipThreshold ubo.materialOptions[OPT_ALPHA_CLIP_THRESHOLD]
#define matSkyboxMipLevel ubo.materialOptions[OPT_SKYBOX_MIP_LEVEL]
#define matMotionBlurMask ubo.materialOptions[OPT_MOTION_BLUR_MASK]

layout(location = 0) out vec4 outRadiance;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outRoughnessMetallic;
layout(location = 3) out vec4 outVelocity;

out float gl_FragDepth;

const float tanNormalYFactor = -1.0;

const float parallaxScale = 0.03;
const float parallaxBias = -0.01;

vec3 sampleIrradiance(in vec3 wN)
{
    if (hasAmbientTexture)
        return texture(irradianceTexture, wN).rgb * ubo.ambientColor.a;
    else
        return ubo.ambientColor.rgb * ubo.ambientColor.a;
}

void main()
{
    vec2 uv = texCoords;
    vec2 gbufTexCoords = gl_FragCoord.xy / ubo.resolution.xy;
    
    vec3 N = normalize(eyeNormal);
    vec3 E = normalize(-eyePosition);
    
    vec3 T;
    if (hasNormalTexture)
    {
        vec2 flow = texture(normalTexture, uv).rg * 2.0 - 1.0;
        T = normalize(
            normalize(eyeBitangent) * flow.x +
            normalize(eyeTangent) * flow.y
        );
    }
    else
    {
        T = normalize(eyeBitangent);
    }
    
    //vec3 worldPos = (ubo.invViewMatrix * vec4(eyePosition, 1.0)).xyz;
    //vec3 worldCamPos = (ubo.invViewMatrix[3]).xyz;
    //vec3 wE = normalize(worldPos - worldCamPos);
    vec3 wN = normalize((ubo.invViewMatrix * vec4(N, 0.0)).xyz);
    //vec3 wR = reflect(wE, wN);
    
    vec4 baseColor = ubo.baseColor;
    if (hasBaseColorTexture)
        baseColor *= texture(baseColorTexture, uv);
    
    float alpha = baseColor.a * matAlpha;
    float denseAlpha = smoothstep(0.0, 0.9, alpha); 
    
    float noise = bayer4x4(gl_FragCoord.xy);
    if (denseAlpha < 0.9)
    {
        if (denseAlpha < noise)
            discard;
    }
    
    vec3 hairColor = toLinear(baseColor.rgb);
    
    // Ambient lighting
    vec3 radiance = hairColor * sampleIrradiance(wN);
    
    // TODO: make uniform
    const vec3 lightColor = vec3(1.0, 1.0, 1.0);
    const float lightEnergy = 1.0f;
    const float specularPower = 128.0;
    
    // Kajiya-Kay anisotropic BRDF
    const vec3 L = ubo.lighVector.xyz;
    float TL = abs(dot(T, L));
    float TE = abs(dot(T, E));
    float sinTL = sqrt(max(0.0, 1.0 - TL * TL));
    float sinTE = sqrt(max(0.0, 1.0 - TE * TE));
    float diffuse = sinTL;
    float specAngle = TL * TE + sinTL * sinTE;
    float specular = pow(max(0.0, specAngle), specularPower);
    radiance += lightColor * (hairColor * diffuse + specular) * lightEnergy;
    
    // Screen-space velocity
    vec2 posScreen = (currPosition.xy / currPosition.w) * 0.5 + 0.5;
    posScreen.y = 1.0 - posScreen.y; // Adapt to Vulkan
    vec2 prevPosScreen = (prevPosition.xy / prevPosition.w) * 0.5 + 0.5;
    prevPosScreen.y = 1.0 - prevPosScreen.y; // Adapt to Vulkan
    vec2 velocity = posScreen - prevPosScreen;
    
    outRadiance = vec4(radiance, 1.0);
    outNormal = vec4(wN * 0.5 + 0.5, 1.0); // fit the normal to 0..1
    outRoughnessMetallic = vec4(0.0, 1.0, 0.0, 0.0);
    outVelocity = vec4(velocity, matMotionBlurMask, 0.0);
    
    gl_FragDepth = gl_FragCoord.z;
}
