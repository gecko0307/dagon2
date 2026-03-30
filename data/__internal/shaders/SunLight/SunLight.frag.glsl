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

float schlickFresnel(float u)
{
    float m = clamp(1.0 - u, 0.0, 1.0);
    float m2 = m * m;
    return m2 * m2 * m;
}

vec3 toLinear(vec3 v)
{
    return pow(v, vec3(2.2));
}

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D normalBuffer;
layout(set = 2, binding = 2) uniform sampler2D roughnessMetallicBuffer;
layout(set = 2, binding = 3) uniform sampler2D depthBuffer;
layout(set = 2, binding = 4) uniform sampler2DArrayShadow shadowTextureArray;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    mat4 invProjectionMatrix;
    mat4 shadowMatrix1;
    mat4 shadowMatrix2;
    mat4 shadowMatrix3;
    vec4 lighVector;
    vec4 lightColor;
    vec4 shadowTextureResolution;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

float shadowLookup(in sampler2DArrayShadow depths, in float layer, in vec4 coord, in vec2 offset)
{
    float texelSize = 1.0 / ubo.shadowTextureResolution.x;
    vec2 v = offset * texelSize * coord.w;
    vec4 c = (coord + vec4(v.x, v.y, 0.0, 0.0)) / coord.w;
    c.y = 1.0 - c.y;
    c.w = c.z;
    c.z = layer;
    float s = texture(depths, c);
    bool inBounds =
        all(greaterThanEqual(c.xy, vec2(0.0))) &&
        all(lessThanEqual(c.xy, vec2(1.0)));
    return inBounds ? s : 1.0;
}

float shadowLookupPCF(in sampler2DArrayShadow depths, in float layer, in vec4 coord, in float radius)
{
    float s = 0.0;
    float x, y;
    for (y = -radius ; y < radius ; y += 1.0)
    for (x = -radius ; x < radius ; x += 1.0)
    {
        s += shadowLookup(depths, layer, coord, vec2(x, y));
    }
    s /= radius * radius * 4.0;
    return s;
}

float shadowCascadeWeight(in vec4 tc, in float coef)
{
    vec2 proj = vec2(tc.x / tc.w, tc.y / tc.w);
    proj = (1.0 - abs(proj * 2.0 - 1.0)) * coef;
    proj = clamp(proj, 0.0, 1.0);
    return min(proj.x, proj.y);
}

const float eyeSpaceNormalShift = 0.008;
float shadowMapCascaded(in vec3 pos, in vec3 N)
{
    vec3 posShifted = pos + N * eyeSpaceNormalShift;
    vec4 shadowCoord1 = ubo.shadowMatrix1 * vec4(posShifted, 1.0);
    vec4 shadowCoord2 = ubo.shadowMatrix2 * vec4(posShifted, 1.0);
    vec4 shadowCoord3 = ubo.shadowMatrix3 * vec4(posShifted, 1.0);
    
    float s1 = shadowLookupPCF(shadowTextureArray, 0.0, shadowCoord1, 2.0);
    float s2 = shadowLookup(shadowTextureArray, 1.0, shadowCoord2, vec2(0.0, 0.0));
    float s3 = shadowLookup(shadowTextureArray, 2.0, shadowCoord3, vec2(0.0, 0.0));
    
    float w1 = shadowCascadeWeight(shadowCoord1, 8.0);
    float w2 = shadowCascadeWeight(shadowCoord2, 8.0);
    float w3 = shadowCascadeWeight(shadowCoord3, 8.0);
    s3 = mix(1.0, s3, w3); 
    s2 = mix(s3, s2, w2);
    s1 = mix(s2, s1, w1);
    
    return s1;
}

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    vec3 ndc = vec3(texCoords, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePos, 1.0)).xyz;
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb * 2.0 - 1.0);
    vec3 E = normalize(-eyePos);
    vec3 R = reflect(E, N);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, texCoords);
    float f0_scalar = roughnessMetallic.r;
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    float shadingMask = roughnessMetallic.a;
    vec4 color = texture(colorBuffer, texCoords);
    vec3 baseColor = toLinear(color.rgb);
    float sss = color.a;
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
    
    // Based on Hanrahan-Krueger BRDF approximation of isotropic BSSRDF
    // 1.25 scale is used to (roughly) preserve albedo
    // fss90 used to "flatten" retroreflection based on roughness
    float FL = schlickFresnel(NL);
    float FV = schlickFresnel(NE);
    float fss90 = LH * LH * max(roughness, 0.001);
    float fss = mix(1.0, fss90, FL) * mix(1.0, fss90, FV);
    float ss = 1.25 * (fss * (1.0 / max(NL + NE, 0.1) - 0.5) + 0.5);
    
    float shadow = shadowMapCascaded(eyePos, N);
    
    vec3 diffuse = INVPI * baseColor * mix(kD * NL * shadow, vec3(ss), sss) * (1.0 - metallic);
    
    vec3 radiance = (diffuse + (specular * shadow * NL)) * incomingLight;
    
    outColor = vec4(radiance * shadingMask, 1.0f);
}
