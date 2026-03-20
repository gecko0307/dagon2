#version 460

mat3 cotangentFrame(in vec3 N, in vec3 p, in vec2 uv)
{
    vec3 pos_dx = dFdx(p);
    vec3 pos_dy = dFdy(p);
    vec2 st1 = dFdx(uv);
    vec2 st2 = dFdy(uv);
    vec3 T = (st2.y * pos_dx - st1.y * pos_dy) / (st1.x * st2.y - st2.x * st1.y);
    T = normalize(T - N * dot(N, T));
    vec3 B = normalize(cross(N, T));
    return mat3(T, B, N);
}

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

layout(location = 0) in vec3 eyePosition;
layout(location = 1) in vec2 texCoords;
layout(location = 2) in vec3 eyeNormal;
layout(location = 3) in vec3 modelPosition;

#define FLAGS_TEXTURE 0
#define FLAGS_OUTPUT 1

#define TEXFLAG_HAS_BASECOLOR_TEXTURE 1 << 0
#define TEXFLAG_HAS_NORMAL_TEXTURE 1 << 1
#define TEXFLAG_HAS_HEIGHT_TEXTURE 1 << 2
#define TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE 1 << 3
#define TEXFLAG_HAS_EMISSION_TEXTURE 1 << 4
#define TEXFLAG_HAS_SKYBOX_TEXTURE 1 << 5

#define OUTFLAG_DEPTH 1 << 0

#define FPARAM_F0 0
#define FPARAM_SKYBOX_MIP_LEVEL 1

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
layout(set = 2, binding = 1) uniform sampler2D normalTexture;
layout(set = 2, binding = 2) uniform sampler2D heightTexture;
layout(set = 2, binding = 3) uniform sampler2D roughnessMetallicTexture;
layout(set = 2, binding = 4) uniform sampler2D emissionTexture;
layout(set = 2, binding = 5) uniform samplerCube skyboxTexture;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 baseColor;
    vec4 roughnessMetallic;
    vec4 emission;
    vec4 alphaOptions;
    uvec4 flags;
    vec4 fparams;
} ubo;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outRoughnessMetallic;
layout(location = 3) out vec4 outEmission;
layout(location = 4) out vec4 outVelocity;
layout(location = 5) out vec4 outRadiance;

out float gl_FragDepth;

const float ysign = 1.0;

const float parallaxScale = 0.03;
const float parallaxBias = -0.01;

void main()
{
    vec2 uv = texCoords;
    vec3 E = normalize(-eyePosition);
    vec3 N = normalize(eyeNormal);
    
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_NORMAL_TEXTURE) != 0)
    {
        mat3 tangentToEye = cotangentFrame(N, eyePosition, texCoords);
        vec3 tanE = normalize(E * tangentToEye);
        tanE.y = -tanE.y;
        
        if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_HEIGHT_TEXTURE) != 0)
        {
            // Parallax mapping
            float height = texture(heightTexture, texCoords).r;
            uv += (height * parallaxScale + parallaxBias) * tanE.xy;
        }
        
        vec3 tanN = normalize(texture(normalTexture, uv).rgb * 2.0 - 1.0);
        tanN.y *= ysign;
        N = normalize(tangentToEye * tanN);
    }
    
    float shadedMask = ubo.alphaOptions.y;
    float motionBlurMask = ubo.alphaOptions.z;
    
    vec4 baseColor = ubo.baseColor;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BASECOLOR_TEXTURE) != 0)
        baseColor *= texture(baseColorTexture, uv);
    
    float f0 = ubo.fparams[FPARAM_F0];
    
    vec4 roughnessMetallic = ubo.roughnessMetallic;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE) != 0)
        roughnessMetallic = texture(roughnessMetallicTexture, uv);
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    
    vec3 emission = ubo.emission.rgb;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SKYBOX_TEXTURE) != 0)
        emission = textureLod(skyboxTexture, -normalize(modelPosition), ubo.fparams[FPARAM_SKYBOX_MIP_LEVEL]).rgb;
    else if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_EMISSION_TEXTURE) != 0)
    {
        emission *= toLinear(texture(emissionTexture, uv).rgb);
        emission += toLinear(baseColor.rgb) * (1.0 - shadedMask);
    }
    
    float alpha = baseColor.a * ubo.alphaOptions.a;
    if (alpha < ubo.alphaOptions.x) // alpha clipping
        discard;
    
    outColor = vec4(baseColor.rgb, 1.0);
    outNormal = vec4(N, 1.0);
    outRoughnessMetallic = vec4(f0, roughness, metallic, shadedMask);
    outEmission = vec4(emission, 1.0);
    outVelocity = vec4(0.0, 0.0, motionBlurMask, 1.0); // TODO
    outRadiance = vec4(0.0, 0.0, 0.0, 1.0);
    
    if ((ubo.flags[FLAGS_OUTPUT] & OUTFLAG_DEPTH) != 0)
        gl_FragDepth = gl_FragCoord.z;
    else
        gl_FragDepth = 1.0;
}
