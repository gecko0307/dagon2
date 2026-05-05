#version 460

#define PI 3.14159265359
const float PI2 = PI * 2.0;

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

// Brian Karis, "Real Shading in Unreal Engine 4"
vec3 importanceSampleGGX(vec2 Xi, float roughness, vec3 N)
{
    float a = roughness; // * roughness;
    
    // Sample in spherical coordinates
    float phi = PI2 * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a * a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    // Construct tangent space vector
    vec3 H;
    H.x = sinTheta * cos(phi);
    H.y = sinTheta * sin(phi);
    H.z = cosTheta;
    
    // Tangent to world space
    vec3 upVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangentX = normalize(cross(upVector, N));
    vec3 tangentY = cross(N, tangentX);
    return tangentX * H.x + tangentY * H.y + N * H.z;
}

layout(set = 2, binding = 0) uniform sampler2D radianceBuffer;
layout(set = 2, binding = 1) uniform sampler2D depthBuffer;
layout(set = 2, binding = 2) uniform sampler2D colorBuffer;
layout(set = 2, binding = 3) uniform sampler2D normalBuffer;
layout(set = 2, binding = 4) uniform sampler2D roughnessMetallicBuffer;
layout(set = 2, binding = 5) uniform sampler2D prevReflectionBuffer;
layout(set = 2, binding = 6) uniform sampler2D velocityBuffer;

#define FLAGS_MAX_LOD_LEVEL 1

#define FPARAM_TIME 0

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    mat4 invViewMatrix;
    mat4 projectionMatrix;
    mat4 invProjectionMatrix;
    vec4 resolution;
    vec4 fparams; // time
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

vec4 sslr(vec3 P, vec3 R, float roughness)
{
    float roughnessFactor = 1.0 - clamp((roughness - 0.1) / (0.5 - 0.1), 0.0, 1.0);
    const float maxDistance = 4.0;
    const int steps = 40;
    const int refineSteps = 4;
    float invSamples = 1.0 / float(steps);
    vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
    float jitter = hash(texCoords * 467.759 + ubo.fparams[0]) * 0.9;
    const float thickness = 0.2;
    float prevT = 0.0;

    for (int i = 0; i <= steps; i++)
    {
        float t = (float(i) + jitter) * invSamples * maxDistance;

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
            float alpha = clamp(screenFade * distanceFade, 0.0, 1.0) * roughnessFactor;
            return vec4(texture(radianceBuffer, finalUV).rgb * alpha, alpha);
        }

        prevT = t;
    }

    return color;
}

void main()
{
    float depth = texture(depthBuffer, texCoords).x;
    if (depth == 1.0)
    {
        outColor = vec4(0.0, 0.0, 0.0, 0.0);
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
    
    vec2 xi = vec2(hash(texCoords + ubo.fparams[0]), hash(texCoords * 1.1 + ubo.fparams[0]));
    vec3 H = importanceSampleGGX(xi, roughness, N);
    vec3 R = normalize(reflect(E, mix(N, H, roughness)));
    
    float NE = clamp(dot(N, E), 0.0, 1.0);
    
    vec3 baseColor = toLinear(texture(colorBuffer, texCoords).rgb);
    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);
    
    vec3 F = clamp(fresnelRoughness(NE, f0, roughness), 0.0, 1.0);
    
    vec4 reflection = sslr(eyePos, R, roughness);
    reflection = vec4(reflection.rgb * F, reflection.a);
    
    vec2 uvVelocity = texture(velocityBuffer, texCoords).xy;
    vec4 prevReflection = texture(prevReflectionBuffer, texCoords - uvVelocity);
    float velocityLength = length(uvVelocity);
    float alpha = mix(0.05, 1.0, clamp(velocityLength * 30.0, 0.0, 1.0));
    vec4 accumulatedReflection = mix(prevReflection, reflection, alpha);

    outColor = accumulatedReflection;
}
