#version 460

layout(set = 2, binding = 0) uniform sampler2D backgroundColorBuffer;
layout(set = 2, binding = 1) uniform samplerCube specularTexture;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    //vec4 baseColor;
    //vec4 roughnessMetallic;
    //vec4 emission;
    vec4 alphaOptions;
    uvec4 flags;
    vec4 resolution;
} ubo;

layout(location = 0) in vec3 eyePosition;
layout(location = 1) in vec2 texCoords;
layout(location = 2) in vec3 eyeNormal;
layout(location = 3) in vec3 modelPosition;
layout(location = 4) in vec4 currPosition;
layout(location = 5) in vec4 prevPosition;

#define FLAGS_TEXTURE 0
#define FLAGS_MAX_SPECULAR_LOD_LEVEL 1
#define FLAGS_ENTITY 2

#define ENTFLAG_STATIC 1 << 0

#define TEXFLAG_HAS_BASECOLOR_TEXTURE 1 << 0
#define TEXFLAG_HAS_NORMAL_TEXTURE 1 << 1
#define TEXFLAG_HAS_HEIGHT_TEXTURE 1 << 2
#define TEXFLAG_HAS_SPECULAR_TEXTURE 1 << 3

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outVelocity;

out float gl_FragDepth;

vec3 sampleSpecularReflection(in vec3 wN, in float roughnessSqrt)
{
    /*
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SPECULAR_TEXTURE) != 0)
    {
        float lod = roughnessSqrt * float(ubo.flags[FLAGS_MAX_LOD_LEVEL]);
        return textureLod(specularTexture, wN, lod).rgb * ubo.ambientColor.a;
    }
    else
    {
        return ubo.ambientColor.rgb * ubo.ambientColor.a;
    }
    */
    
    float lod = roughnessSqrt * float(ubo.flags[FLAGS_MAX_SPECULAR_LOD_LEVEL]);
    return textureLod(specularTexture, wN, lod).rgb; // * ubo.ambientColor.a;
}

void main()
{
    vec2 gbufTexCoord = gl_FragCoord.xy / ubo.resolution.xy;
    
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePosition, 1.0)).xyz;
    
    vec2 posScreen = (currPosition.xy / currPosition.w) * 0.5 + 0.5;
    posScreen.y = 1.0 - posScreen.y;
    vec2 prevPosScreen = (prevPosition.xy / prevPosition.w) * 0.5 + 0.5;
    prevPosScreen.y = 1.0 - prevPosScreen.y;
    vec2 velocity = posScreen - prevPosScreen;
    
    vec3 N = normalize(eyeNormal);
    vec3 E = normalize(-eyePosition);
    
    vec3 worldCamPos = (ubo.invViewMatrix[3]).xyz;
    vec3 wE = normalize(worldPos - worldCamPos);
    vec3 wN = normalize((ubo.invViewMatrix * vec4(N, 0.0)).xyz);
    vec3 wR = reflect(wE, wN);
    
    const float ior = 1.02;
    vec3 RR = refract(E, N, 1.0 / ior);
    
    const float roughness = 0.01;
    vec3 reflection = sampleSpecularReflection(wR, sqrt(roughness));
    
    float fresnel = pow(1.0 - max(dot(E, N), 0.0), 5.0);
    
    const float refractionStrength = 0.1;
    vec2 offset = RR.xy * refractionStrength;
    vec2 refractedUV = gbufTexCoord + offset;
    float chromaticAberration = 0.01;
    vec3 refraction;
    refraction.r = texture(backgroundColorBuffer, refractedUV + offset * chromaticAberration).r;
    refraction.g = texture(backgroundColorBuffer, refractedUV).g;
    refraction.b = texture(backgroundColorBuffer, refractedUV - offset * chromaticAberration).b;
    
    vec3 outputColor = mix(refraction * 0.5, reflection, fresnel);
    
    float motionBlurMask = ubo.alphaOptions.z;
    float staticMask = float(ubo.flags[FLAGS_ENTITY] & ENTFLAG_STATIC);
    
    outColor = vec4(outputColor, 1.0);
    outVelocity = vec4(velocity, motionBlurMask, staticMask);
    
    gl_FragDepth = gl_FragCoord.z;
}
