#version 460

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

/*
layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
layout(set = 2, binding = 1) uniform sampler2D normalTexture;
layout(set = 2, binding = 2) uniform sampler2D heightTexture;
layout(set = 2, binding = 3) uniform sampler2D roughnessMetallicTexture;
layout(set = 2, binding = 4) uniform sampler2D emissionTexture;
layout(set = 2, binding = 5) uniform samplerCube specularTexture;
layout(set = 2, binding = 6) uniform samplerCube irradianceTexture;
*/

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    //vec4 baseColor;
    //vec4 roughnessMetallic;
    //vec4 emission;
    vec4 ambientColor;
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

/*
vec3 sampleSpecularReflection(in vec3 wN, in float roughnessSqrt)
{
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SPECULAR_TEXTURE) != 0)
    {
        float lod = roughnessSqrt * float(ubo.flags[FLAGS_MAX_SPECULAR_LOD_LEVEL]);
        return textureLod(specularTexture, wN, lod).rgb * ubo.ambientColor.a;
    }
    else
    {
        return ubo.ambientColor.rgb * ubo.ambientColor.a;
    }
}
*/

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
    
    // TODO
    vec4 baseColor = vec4(1.0, 1.0, 1.0, 1.0);
    
    //float f0 = ubo.fparams[FPARAM_F0];
    
    /*
    vec4 roughnessMetallic = ubo.roughnessMetallic;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE) != 0)
        roughnessMetallic = texture(roughnessMetallicTexture, uv);
    float roughness = max(roughnessMetallic.g, 0.01);
    float metallic = roughnessMetallic.b;
    */
    
    /*
    vec3 emission = ubo.emission.rgb;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SKYBOX_TEXTURE) != 0)
        emission *= textureLod(skyboxTexture, -normalize(modelPosition), ubo.fparams[FPARAM_SKYBOX_MIP_LEVEL]).rgb;
    else
    {
        if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_EMISSION_TEXTURE) != 0)
            emission *= toLinear(texture(emissionTexture, uv).rgb);
        
        emission += toLinear(baseColor.rgb) * (1.0 - shadedMask);
    }
    */
    
    float alpha = baseColor.a * ubo.alphaOptions.a;
    
    vec3 outputColor = toLinear(baseColor.rgb);
    
    float shadedMask = ubo.alphaOptions.y;
    float motionBlurMask = ubo.alphaOptions.z;
    
    //float sss = ubo.fparams[FPARAM_SSS];
    
    // TODO: fog
    
    // Screen-space velocity
    vec2 posScreen = (currPosition.xy / currPosition.w) * 0.5 + 0.5;
    posScreen.y = 1.0 - posScreen.y; // Adapt to Vulkan
    vec2 prevPosScreen = (prevPosition.xy / prevPosition.w) * 0.5 + 0.5;
    prevPosScreen.y = 1.0 - prevPosScreen.y; // Adapt to Vulkan
    vec2 velocity = posScreen - prevPosScreen;
    
    float staticMask = float(ubo.flags[FLAGS_ENTITY] & ENTFLAG_STATIC);
    
    outColor = vec4(outputColor, alpha);
    outVelocity = vec4(velocity, motionBlurMask, staticMask);
    
    //if ((ubo.flags[FLAGS_OUTPUT] & OUTFLAG_DEPTH) != 0)
        gl_FragDepth = gl_FragCoord.z;
    //else
    //    gl_FragDepth = 1.0;
}
