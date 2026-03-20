#version 460

#define PI 3.14159265359
const float PI2 = PI * 2.0;
const float INVPI = 1.0 / PI;

// Converts normalized device coordinates to eye space position
vec3 unproject(mat4 invProjMatrix, vec3 ndc)
{
    vec4 clipPos = vec4(ndc * 2.0 - 1.0, 1.0);
    vec4 res = invProjMatrix * clipPos;
    return res.xyz / res.w;
}

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

vec3 fresnelRoughness(float cosTheta, vec3 f0, float roughness)
{
    return f0 + (max(vec3(1.0 - roughness), f0) - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

#define FLAGS_TEXTURE 0
#define FLAGS_MAX_LOD_LEVEL 1

#define TEXFLAG_HAS_SPECULAR_TEXTURE 1 << 0
#define TEXFLAG_HAS_IRRADIANCE_TEXTURE 1 << 1
#define TEXFLAG_HAS_BRDF_LUT 1 << 2

#define FPARAM_F0 0

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D normalBuffer;
layout(set = 2, binding = 2) uniform sampler2D roughnessMetallicBuffer;
layout(set = 2, binding = 3) uniform sampler2D depthBuffer;
layout(set = 2, binding = 4) uniform samplerCube specularTexture;
layout(set = 2, binding = 5) uniform samplerCube irradianceTexture;
layout(set = 2, binding = 6) uniform sampler2D brdfLUT;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    mat4 invViewMatrix;
    mat4 invProjectionMatrix;
    vec4 ambientColor;
    uvec4 flags;
    vec4 fparams;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

vec3 sampleSpecularReflection(in vec3 wN, in float roughnessSqrt)
{
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_SPECULAR_TEXTURE) != 0)
    {
        float lod = roughnessSqrt * float(ubo.flags[FLAGS_MAX_LOD_LEVEL]);
        return textureLod(specularTexture, wN, lod).rgb * ubo.ambientColor.a;
    }
    else
    {
        return ubo.ambientColor.rgb * ubo.ambientColor.a;
    }
}

vec3 sampleIrradiance(in vec3 wN)
{
    if ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_IRRADIANCE_TEXTURE) != 0)
    {
        return texture(irradianceTexture, wN).rgb * ubo.ambientColor.a;
    }
    else
    {
        return ubo.ambientColor.rgb * ubo.ambientColor.a;
    }
}

// TODO: read from occlusion buffer
const float occlusion = 1.0;

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    vec3 ndc = vec3(texCoords, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePos, 1.0)).xyz;
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb);
    vec3 E = normalize(-eyePos);
    vec3 R = reflect(E, N);
    float NE = clamp(dot(N, E), 0.0, 1.0);
    
    vec3 worldCamPos = (ubo.invViewMatrix[3]).xyz;
    vec3 wE = normalize(worldPos - worldCamPos);
    vec3 wN = normalize((ubo.invViewMatrix * vec4(N, 0.0)).xyz);
    vec3 wR = reflect(wE, wN);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, texCoords);
    float f0_scalar = roughnessMetallic.r;
    float roughness = sqrt(roughnessMetallic.g);
    float metallic = roughnessMetallic.b;
    float shadingMask = roughnessMetallic.a;
    vec3 baseColor = toLinear(texture(colorBuffer, texCoords).rgb);
    
    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);
    
    vec3 irradiance = sampleIrradiance(wN);
    vec3 reflection = sampleSpecularReflection(wR, roughness);
    vec2 brdf = ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BRDF_LUT) != 0)?
        texture(brdfLUT, vec2(NE, roughness)).rg :
        vec2(1.0, 0.0);
    
    vec3 F = max(fresnelRoughness(NE, f0, roughness), 0.0);
    
    // Single scattering
    //vec3 kD = (1.0 - F) * (1.0 - metallic);
    //vec3 diffuse = kD * irradiance * baseColor;
    //vec3 specular = reflection * clamp(F * brdf.x + brdf.y, 0.0, 1.0);
    //radiance += (diffuse + specular) * occlusion;
    
    // Multiple scattering (Fdez-Agüera)
    vec3 diffuse = baseColor * (1.0 - metallic) * (1.0 - f0_scalar);
    vec3 FssEss = clamp(F * brdf.x + brdf.y, 0.0, 1.0);
    float Ems = (1.0 - (brdf.x + brdf.y));
    vec3 Favg = f0 + (1.0 - f0) / 21.0;
    vec3 FmsEms = Ems * FssEss * Favg / (1.0 - Favg * Ems);
    vec3 kD = diffuse * (1.0 - FssEss - FmsEms);
    vec3 radiance = FssEss * reflection + (FmsEms + kD) * irradiance;
    
    outColor = vec4(radiance * shadingMask, 1.0f);
}
