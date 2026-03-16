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

#define TEXFLAG_HAS_BRDF_LUT 1 << 0

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D normalBuffer;
layout(set = 2, binding = 2) uniform sampler2D roughnessMetallicBuffer;
layout(set = 2, binding = 3) uniform sampler2D depthBuffer;
layout(set = 2, binding = 4) uniform samplerCube ambientTexture;
layout(set = 2, binding = 5) uniform sampler2D brdfLUT;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    mat4 invViewMatrix;
    mat4 invProjectionMatrix;
    uint flags[4];
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

vec3 ambient(in vec3 wN, in float perceptualRoughness)
{
    ivec2 envMapSize = textureSize(ambientTexture, 0);
    float resolution = float(max(envMapSize.x, envMapSize.y));
    float lod = log2(resolution) * perceptualRoughness;
    return textureLod(ambientTexture, wN, lod).rgb;
}

const float reflectivity = 1.0;
const float ambientEnergy = 1.0;

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    vec3 ndc = vec3(texCoords, depth);
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    vec3 worldPos = (ubo.invViewMatrix * vec4(eyePos, 1.0)).xyz;
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb);
    vec3 E = normalize(-eyePos);
    vec3 R = reflect(E, N);
    
    vec3 camPos = (ubo.invViewMatrix[3]).xyz;
    vec3 wE = normalize(worldPos - camPos);
    vec3 wN = normalize((vec4(N, 0.0) * ubo.viewMatrix).xyz);
    vec3 wR = reflect(wE, wN);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, texCoords);
    float shadedMask = roughnessMetallic.r;
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    vec3 baseColor = toLinear(texture(colorBuffer, texCoords).rgb);
    vec3 f0 = mix(vec3(0.04), baseColor, metallic);
    
    vec3 radiance = vec3(0.0);
    
    float NE = max(dot(N, E), 0.0);
    
    vec3 irradiance = ambient(wN, 0.99); // TODO: support separate irradiance map
    vec3 reflection = ambient(wR, sqrt(roughness)) * reflectivity;
    vec3 F = clamp(fresnelRoughness(NE, f0, roughness), 0.0, 1.0);
    vec3 kD = (1.0 - F) * (1.0 - metallic);
    vec2 brdf = ((ubo.flags[FLAGS_TEXTURE] & TEXFLAG_HAS_BRDF_LUT) != 0)?
        texture(brdfLUT, vec2(NE, roughness)).rg :
        vec2(1.0, 0.0);
    vec3 diffuse = kD * irradiance * baseColor;
    vec3 specular = reflection * clamp(F * brdf.x + brdf.y, 0.0, 1.0) * (1.0 - roughness);
    const float occlusion = 1.0;
    radiance += (diffuse + specular) * occlusion * ambientEnergy;
    
    outColor = vec4(radiance * shadedMask, 1.0f);
}
