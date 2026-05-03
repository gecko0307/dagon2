#version 460

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

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.7, 4.8))) * 43758.5);
}

vec3 randomSpherePoint(vec2 uv)
{
    float ang1 = hash(uv) * 6.283185;
    float ang2 = hash(uv + 0.5) * 3.141592;
    return vec3(sin(ang2)*cos(ang1), sin(ang2)*sin(ang1), cos(ang2));
}

vec3 sampleHemisphere(vec3 N, vec2 uv) {
    vec3 v = randomSpherePoint(uv); 
    if (dot(v, N) > 0.0)
        return v;
    else
        return -v;
}

layout(set = 2, binding = 0) uniform sampler2D radianceBuffer;
layout(set = 2, binding = 1) uniform sampler2D depthBuffer;
layout(set = 2, binding = 2) uniform sampler2D colorBuffer;
layout(set = 2, binding = 3) uniform sampler2D normalBuffer;
layout(set = 2, binding = 4) uniform sampler2D roughnessMetallicBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    mat4 invViewMatrix;
    mat4 projectionMatrix;
    mat4 invProjectionMatrix;
    vec4 resolution;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

vec3 sslr(vec3 P, vec3 R)
{
    const float maxDistance = 5.0;
    const int steps = 20;
    float invSamples = 1.0 / float(steps);
    vec3 color = vec3(0.0, 0.0, 0.0);
    const float bias = 0.1;
    float jitter = hash(texCoords * 467.759);
    const float thickness = 0.1;
    for (int i = 0; i <= steps; i++)
    {
        float t = bias + (float(i) + jitter) * invSamples * maxDistance;
        
        vec3 samplePos = P + R * t;
        vec4 clip = ubo.projectionMatrix * vec4(samplePos, 1.0);
        clip /= clip.w;
        vec2 uv = clip.xy * 0.5 + 0.5;
        uv.y = 1.0 - uv.y;
        
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec3(0.0);
        
        float depth = texture(depthBuffer, uv).x;
        vec3 ndc = vec3(uv, depth);
        vec3 hitPos = unproject(ubo.invProjectionMatrix, ndc);
        
        if (samplePos.z < hitPos.z && samplePos.z > hitPos.z - thickness)
        {
            vec2 edgeFactor = smoothstep(vec2(0.0), vec2(0.2), uv) * (1.0 - smoothstep(vec2(0.8), vec2(1.0), uv));
            float screenFade = edgeFactor.x * edgeFactor.y;
            float distanceFade = 1.0 - clamp(t / maxDistance, 0.0, 1.0);
            return texture(radianceBuffer, uv).rgb * screenFade * distanceFade;
        }
    }

    return color;
}

void main()
{
    vec3 original = texture(radianceBuffer, texCoords).rgb;
    
    float depth = texture(depthBuffer, texCoords).x;
    if (depth == 1.0)
    {
        outColor = vec4(original, 1.0);
        return;
    }
    
    vec3 ndc = vec3(texCoords, depth);
    ndc.y = 1.0 - ndc.y;
    vec3 eyePos = unproject(ubo.invProjectionMatrix, ndc);
    
    vec3 N = normalize(texture(normalBuffer, texCoords).rgb * 2.0 - 1.0);
    vec3 E = normalize(eyePos);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, texCoords);
    float f0_scalar = roughnessMetallic.r;
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    float shadingMask = roughnessMetallic.a;
    
    vec3 rN = normalize(sampleHemisphere(N, texCoords));
    vec3 mixedNormal = mix(N, rN, roughness * 0.5);
    
    vec3 R = normalize(reflect(E, mixedNormal));
    float NE = clamp(dot(N, E), 0.0, 1.0);
    
    vec3 baseColor = toLinear(texture(colorBuffer, texCoords).rgb);
    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);
    
    vec3 F = clamp(fresnelRoughness(NE, f0, roughness), 0.0, 1.0);
    
    vec3 reflection = sslr(eyePos, R) * F;

    outColor = vec4(original + reflection * shadingMask, 1.0);
}
