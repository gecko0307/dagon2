#version 460

// Converts normalized device coordinates to eye space position
vec3 unproject(mat4 invProjMatrix, vec3 ndc)
{
    vec4 clipPos = vec4(ndc * 2.0 - 1.0, 1.0);
    vec4 res = invProjMatrix * clipPos;
    return res.xyz / res.w;
}

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

#define FLAGS_TEXTURE 0

#define TEXFLAG_HAS_BASECOLOR_TEXTURE 1 << 0
#define TEXFLAG_HAS_NORMAL_TEXTURE 1 << 1
#define TEXFLAG_HAS_HEIGHT_TEXTURE 1 << 2
#define TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE 1 << 3
#define TEXFLAG_HAS_EMISSION_TEXTURE 1 << 4

#define FPARAM_F0 0

layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
layout(set = 2, binding = 1) uniform sampler2D normalTexture;
layout(set = 2, binding = 2) uniform sampler2D heightTexture;
layout(set = 2, binding = 3) uniform sampler2D roughnessMetallicTexture;
layout(set = 2, binding = 4) uniform sampler2D emissionTexture;
layout(set = 2, binding = 5) uniform sampler2D depthBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    mat4 invModelMatrix;
    mat4 invProjectionMatrix;
    vec4 baseColor;
    vec4 roughnessMetallic;
    vec4 emission;
    vec4 alphaOptions;
    uvec4 flags;
    vec4 fparams;
    vec4 resolution;
    vec4 decalDirection;
} ubo;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outRoughnessMetallic;
layout(location = 3) out vec4 outEmission;

const float ysign = 1.0;

const float parallaxScale = 0.03;
const float parallaxBias = -0.01;

void main()
{
    vec2 gbufTexCoord = gl_FragCoord.xy / ubo.resolution.xy;

    float depth = texture(depthBuffer, gbufTexCoord).x;
    vec3 ndc = vec3(gbufTexCoord, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    
    vec3 E = normalize(-eyePos);
    
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePos, 1.0)).xyz;
    vec3 objPos = (ubo.invModelMatrix * vec4(worldPos, 1.0)).xyz;
    
    // Perform bounds check to discard fragments outside the decal box
    if (abs(objPos.x) > 1.0 || abs(objPos.y) > 1.0 || abs(objPos.z) > 1.0) discard;
    
    // Normal
    vec3 fdx = dFdx(eyePos);
    vec3 fdy = dFdy(eyePos);
    vec3 N = normalize(cross(fdx, fdy));
    
    // Texcoord (go from -1..1 to 0..1)
    vec2 texCoords = objPos.xz * 0.5 + 0.5;
    //texCoords = (textureMatrix * vec3(texCoords, 1.0)).xy;
    vec2 uv = texCoords;
    
    float normalAlpha = 0.0;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_NORMAL_TEXTURE) != 0)
    {
        mat3 tangentToEye = cotangentFrame(N, eyePos, texCoords);
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
        
        normalAlpha = 1.0;
    }
    
    float shadedMask = ubo.alphaOptions.y;
    
    const float colorAlpha = 1.0;
    vec4 baseColor = ubo.baseColor;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BASECOLOR_TEXTURE) != 0)
    {
        baseColor *= texture(baseColorTexture, uv);
    }
    
    float f0 = ubo.fparams[FPARAM_F0];
    
    const float rougnessMetallicAlpha = 1.0;
    vec4 roughnessMetallic = ubo.roughnessMetallic;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_ROUGHNESSMETALLIC_TEXTURE) != 0)
        roughnessMetallic = texture(roughnessMetallicTexture, uv);
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    
    const float emissionAlpha = 1.0;
    vec3 emission = ubo.emission.rgb;
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_EMISSION_TEXTURE) != 0)
    {
        emission *= toLinear(texture(emissionTexture, uv).rgb);
        emission += toLinear(baseColor.rgb) * (1.0 - shadedMask);
    }
    
    float alpha = baseColor.a * ubo.alphaOptions.a;
    
    outColor = vec4(baseColor.rgb, colorAlpha * alpha);
    outNormal = vec4(N, normalAlpha * alpha);
    outRoughnessMetallic = vec4(f0, roughness, metallic, rougnessMetallicAlpha * alpha);
    outEmission = vec4(emission, emissionAlpha * alpha);
}
