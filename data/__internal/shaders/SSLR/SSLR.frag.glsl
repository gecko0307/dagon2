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

#define FLAGS_MAX_LOD_LEVEL 1

#define FPARAM_TIME 0

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

vec4 sslr(vec3 P, vec3 R, float roughness)
{
    const float maxDistance = 5.0;
    const int steps = 40;
    const int refineSteps = 4;
    float invSamples = 1.0 / float(steps);
    vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
    float jitter = hash(texCoords * 467.759) * 0.8;
    const float thickness = 0.2;
    float prevT = 0.0;

    for (int i = 0; i <= steps; i++)
    {
        float t = (float(i) + 0.5 + jitter) * invSamples * maxDistance;

        vec3 samplePos = P + R * t;
        vec4 clip = ubo.projectionMatrix * vec4(samplePos, 1.0);
        clip /= clip.w;
        vec2 uv = clip.xy * 0.5 + 0.5;
        uv.y = 1.0 - uv.y;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
            return vec4(0.0);

        float depth = texture(depthBuffer, uv).x;
        vec3 ndc = vec3(uv, depth);
        vec3 hitPos = unproject(ubo.invProjectionMatrix, ndc);

        if (samplePos.z < hitPos.z && samplePos.z > hitPos.z - thickness)
        {
            float tLo = prevT;
            float tHi = t;

            for (int j = 0; j < refineSteps; j++)
            {
                float tMid = 0.5 * (tLo + tHi);
                vec3 midPos = P + R * tMid;
                vec4 midClip = ubo.projectionMatrix * vec4(midPos, 1.0);
                midClip /= midClip.w;
                vec2 midUV = midClip.xy * 0.5 + 0.5;
                midUV.y = 1.0 - midUV.y;

                if (midUV.x < 0.0 || midUV.x > 1.0 || midUV.y < 0.0 || midUV.y > 1.0)
                {
                    tHi = tMid;
                    continue;
                }

                float midDepth = texture(depthBuffer, midUV).x;
                vec3 midHitPos = unproject(ubo.invProjectionMatrix, vec3(midUV, midDepth));

                if (midPos.z < midHitPos.z)
                    tHi = tMid;
                else
                    tLo = tMid;
            }

            float tFinal = tHi;
            vec3 finalPos = P + R * tFinal;
            vec4 finalClip = ubo.projectionMatrix * vec4(finalPos, 1.0);
            finalClip /= finalClip.w;
            vec2 finalUV = finalClip.xy * 0.5 + 0.5;
            finalUV.y = 1.0 - finalUV.y;

            vec2 edgeFactor = smoothstep(vec2(0.0), vec2(0.2), finalUV) * (1.0 - smoothstep(vec2(0.8), vec2(1.0), finalUV));
            float screenFade = edgeFactor.x * edgeFactor.y;
            float distanceFade = 1.0 - clamp(tFinal / maxDistance, 0.0, 1.0);
            float alpha = clamp(screenFade * distanceFade, 0.0, 1.0);
            return vec4(texture(radianceBuffer, finalUV).rgb * alpha, alpha);
        }

        prevT = t;
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
    
    vec3 rndN = normalize(sampleHemisphere(N, texCoords));
    vec3 stochN = mix(N, rndN, roughness * 0.2);
    
    vec3 R = normalize(reflect(E, stochN));
    float NE = clamp(dot(N, E), 0.0, 1.0);
    
    vec3 baseColor = toLinear(texture(colorBuffer, texCoords).rgb);
    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);
    
    vec3 F = clamp(fresnelRoughness(NE, f0, roughness), 0.0, 1.0);
    
    vec4 reflection = sslr(eyePos, R, roughness);
    vec3 indirectSpecular = reflection.rgb * F;

    outColor = vec4(mix(original, indirectSpecular, reflection.a), 1.0);
}
