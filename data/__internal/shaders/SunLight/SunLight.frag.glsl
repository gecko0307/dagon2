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

// Trowbridge-Reitz GGX normal distribution
float distributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float num = a2;
    float denom = max(NdotH2 * (a2 - 1.0) + 1.0, 0.001);
    denom = PI * denom * denom;
    return num / denom;
}

float geometrySchlickGGX(float NdotV, float k)
{
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return num / denom;
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = geometrySchlickGGX(NdotV, k);
    float ggx1  = geometrySchlickGGX(NdotL, k);
    return ggx1 * ggx2;
}

vec3 fresnelRoughness(float cosTheta, vec3 f0, float roughness)
{
    return f0 + (max(vec3(1.0 - roughness), f0) - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D normalBuffer;
layout(set = 2, binding = 2) uniform sampler2D roughnessMetallicBuffer;
layout(set = 2, binding = 3) uniform sampler2D depthBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invProjectionMatrix;
    vec4 lighVector;
    vec4 lightColor;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    vec3 ndc = vec3(texCoords, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb);
    vec3 E = normalize(-eyePos);
    vec3 R = reflect(E, N);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, texCoords);
    float f0_scalar = roughnessMetallic.r;
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    float shadingMask = roughnessMetallic.a;
    vec3 baseColor = toLinear(texture(colorBuffer, texCoords).rgb);
    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);

    vec3 L = ubo.lighVector.xyz;
    float NL = max(dot(N, L), 0.0);
    float NE = max(dot(N, E), 0.0);
    vec3 H = normalize(E + L);
    float LH = max(dot(L, H), 0.0);
    
    float NDF = distributionGGX(N, H, roughness);
    float G = geometrySmith(N, E, L, roughness);
    vec3 F = fresnelRoughness(max(dot(H, E), 0.0), f0, roughness);
    
    vec3 kD = (1.0 - F);
    vec3 specular = (NDF * G * F) / max(4.0 * max(dot(N, E), 0.0) * NL, 0.001);
    
    vec3 incomingLight = toLinear(ubo.lightColor.rgb) * ubo.lightColor.a;
    
    const float shadow = 1.0;
    const float occlusion = shadow * 1.0;
    vec3 diffuse = INVPI * baseColor * (kD * NL * occlusion) * (1.0 - metallic);
    
    vec3 radiance = (diffuse + (specular * shadow * NL)) * incomingLight;
    
    outColor = vec4(radiance * shadingMask, 1.0f);
}
