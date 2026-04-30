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

vec3 fresnel(float cosTheta, vec3 f0)
{
    return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float distributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float num = a2;
    float denom = max(NdotH2 * (a2 - 1.0) + 1.0, 0.00001);
    const float Pi = 3.14159265359;
    denom = Pi * denom * denom;
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

float schlickFresnel(float u)
{
    float m = clamp(1.0 - u, 0.0, 1.0);
    float m2 = m * m;
    return m2 * m2 * m;
}

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D normalBuffer;
layout(set = 2, binding = 2) uniform sampler2D roughnessMetallicBuffer;
layout(set = 2, binding = 3) uniform sampler2D depthBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 invViewMatrix;
    mat4 invModelMatrix;
    mat4 invProjectionMatrix;
    vec4 resolution;
    vec4 lightPosition;
    vec4 lightColor;
    vec4 lightParams;
    uvec4 iparams;
} ubo;

#define LIGHT_TYPE_AREA_SPHERE 1

layout(location = 0) out vec4 outColor;

const float lightDiffuse = 1.0;
const float lightSpecular = 1.0;

vec3 lightRadianceAreaSphere(
    in vec3 pos, 
    in vec3 N, 
    in vec3 E, 
    in vec3 baseColor,
    in float f0_scalar,
    in float roughness, 
    in float metallic, 
    in float subsurface,
    in float occlusion)
{
    vec3 R = reflect(E, N);

    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);

    vec3 positionToLightSource = ubo.lightPosition.xyz - pos;
    float distanceToLight = length(positionToLightSource);
    float attenuation = pow(clamp(1.0 - (distanceToLight / max(ubo.lightParams.x, 0.001)), 0.0, 1.0), 4.0) * ubo.lightParams.z;

    vec3 Lpt = normalize(positionToLightSource);

    vec3 centerToRay = dot(positionToLightSource, R) * R - positionToLightSource;
    vec3 closestPoint = positionToLightSource + centerToRay * clamp(ubo.lightParams.y / max(length(centerToRay), 0.001), 0.0, 1.0);
    vec3 L = normalize(closestPoint);  

    float NL = max(dot(N, Lpt), 0.0);
    float NE = max(dot(N, E), 0.0);
    vec3 H = normalize(E + L);
    float LH = max(dot(L, H), 0.0);

    float NDF = distributionGGX(N, H, roughness);
    float G = geometrySmith(N, E, L, roughness);
    vec3 F = fresnel(max(dot(H, E), 0.0), f0);
    
    vec3 kD = vec3(1.0) - F;
    
    // Based on Hanrahan-Krueger BRDF approximation of isotropic BSSRDF
    // 1.25 scale is used to (roughly) preserve base color
    // fss90 used to "flatten" retroreflection based on roughness
    float FL = schlickFresnel(NL);
    float FV = schlickFresnel(NE);
    float fss90 = LH * LH * max(roughness, 0.00001);
    float fss = mix(1.0, fss90, FL) * mix(1.0, fss90, FV);
    float ss = 1.25 * (fss * (1.0 / max(NL + NE, 0.1) - 0.5) + 0.5);
    
    vec3 diffuse = INVPI * baseColor * mix(kD * NL * occlusion, vec3(ss), subsurface) * (1.0 - metallic);

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, E), 0.0) * NL;
    vec3 specular = numerator / max(denominator, 0.00001);
    
    vec3 lightColorLinear = toLinear(ubo.lightColor.rgb);
    
    vec3 incomingLight = lightColorLinear * attenuation;
    vec3 radiance = (diffuse * lightDiffuse + specular * lightSpecular * NL) * incomingLight;

    return radiance;
}

void main()
{
    vec2 gbufTexCoord = gl_FragCoord.xy / ubo.resolution.xy;
    
    float depth = texture(depthBuffer, gbufTexCoord).x;
    vec3 ndc = vec3(gbufTexCoord, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePos, 1.0)).xyz;
    
    vec3 N = normalize(texture(normalBuffer, gbufTexCoord).rgb * 2.0 - 1.0);
    vec3 E = normalize(-eyePos);
    vec3 R = reflect(E, N);
    float NE = clamp(dot(N, E), 0.0, 1.0);
    
    vec3 worldCamPos = (ubo.invViewMatrix[3]).xyz;
    vec3 wE = normalize(worldPos - worldCamPos);
    vec3 wN = normalize((ubo.invViewMatrix * vec4(N, 0.0)).xyz);
    vec3 wR = reflect(wE, wN);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, gbufTexCoord);
    float f0_scalar = roughnessMetallic.r;
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    float shadingMask = roughnessMetallic.a;
    vec4 color = texture(colorBuffer, gbufTexCoord);
    vec3 baseColor = toLinear(color.rgb);
    float sss = color.a;
    
    // TODO
    //float shadow = shadowMap(worldPos);
    
    vec3 radiance;
    if (ubo.iparams.x == LIGHT_TYPE_AREA_SPHERE)
        radiance = lightRadianceAreaSphere(eyePos, N, E, baseColor, f0_scalar, roughness, metallic, sss, 1.0);
    // TODO: support other light types
    else
        radiance = vec3(0.0, 0.0, 0.0);
    
    outColor = vec4(radiance * shadingMask, 1.0);
}
