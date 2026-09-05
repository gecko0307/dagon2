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

/*
 * Permuted congruential generator
 * based on pcg_oneseq_32_step_r and pcg_output_rxs_m_xs_32_32
 * from https://github.com/imneme/pcg-c/
 */
uint pcg(uint x)
{
    uint state = x * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float hash2(uvec2 v)
{
    return pcg(v.x ^ (v.y * 1103515245u));
}

float hash3(uvec3 v)
{
    return pcg(v.x ^ (v.y * 1103515245u) ^ (v.z * 134775813u));
}

float hash(vec2 uv)
{
    uvec2 ip = uvec2(floatBitsToUint(uv.x), floatBitsToUint(uv.y));
    return float(hash2(ip)) / float(0xFFFFFFFFu);
}

// Brian Karis, "Real Shading in Unreal Engine 4"
vec3 importanceSampleGGX(vec2 Xi, float roughness, vec3 N)
{
    float a = roughness;
    
    // Sample in spherical coordinates
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a * a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float phi = PI2 * Xi.x;
    
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
layout(set = 2, binding = 7) uniform sampler2D brdfLUT;

#define FLAGS_MAX_LOD_LEVEL 1

#define FPARAM_TIME_DELTA 1

layout(set = 3, binding = 0) uniform UniformBuffer
{
    mat4 viewMatrix;
    mat4 invViewMatrix;
    mat4 projectionMatrix;
    mat4 invProjectionMatrix;
    vec4 resolution;
    vec4 fparams; // [time, timeDelta, maxDistance, invSamples]
    vec4 fparams2; // [hitThickness, velocitySensitivity, historyWeight, motionWeight]
    uvec4 iparams; // [hasBRDFLut, samples, refineSamples, 0]
} ubo;

#define time ubo.fparams.x
#define timeDelta ubo.fparams.y
#define maxDistance ubo.fparams.z
#define invSamples ubo.fparams.w

#define hitThickness ubo.fparams2.x
#define velocitySensitivity ubo.fparams2.y
#define historyWeight ubo.fparams2.z
#define motionWeight ubo.fparams2.w

#define hasBRDFLut bool(ubo.iparams.x)
#define samples ubo.iparams.y
#define refineSamples ubo.iparams.z

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

/*
 * Stochastic screen-space ray tracing function.
 * Samples radiance buffer along the eye-space vector R from eye-space position P.
 * Roughness is used to reduce noise: fade out/early exit for surfaces that are too rough.
 */
vec4 sslr(vec3 P, vec3 R, float roughness)
{
    float roughnessFactor = 1.0 - clamp((roughness - 0.2) / (0.7 - 0.2), 0.0, 1.0);
    if (roughnessFactor <= 0.0)
        return vec4(0.0);

    vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
    float jitter = hash(texCoords * 467.759 + time) * 0.9;
    float prevT = 0.0;

    float P00 = ubo.projectionMatrix[0][0];
    float P11 = ubo.projectionMatrix[1][1];
    float P20 = ubo.projectionMatrix[2][0];
    float P21 = ubo.projectionMatrix[2][1];
    float P22 = ubo.projectionMatrix[2][2];
    float P23 = ubo.projectionMatrix[3][2];
    float P32 = ubo.projectionMatrix[2][3];
    
    float I02 = ubo.invProjectionMatrix[0][2];
    float I12 = ubo.invProjectionMatrix[1][2];
    float I22 = ubo.invProjectionMatrix[2][2];
    float I32 = ubo.invProjectionMatrix[3][2];
    float I03 = ubo.invProjectionMatrix[0][3];
    float I13 = ubo.invProjectionMatrix[1][3];
    float I23 = ubo.invProjectionMatrix[2][3];
    float I33 = ubo.invProjectionMatrix[3][3];

    for (uint i = 0; i <= samples; i++)
    {
        float t = (float(i) + jitter) * invSamples * maxDistance;
        vec3 samplePos = P + R * t;

        // Fast projection, instead of multiplying ubo.projectionMatrix * vec4(samplePos, 1.0)
        float clipW = samplePos.z * P32; 
        float invW = 1.0 / clipW;

        vec2 uv;
        uv.x = (samplePos.x * P00 + samplePos.z * P20) * invW;
        uv.y = (samplePos.y * P11 + samplePos.z * P21) * invW;
        
        // Convert to UV space (reverse Y for Vulkan)
        uv = uv * 0.5 + 0.5;
        uv.y = 1.0 - uv.y;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
            break;

        float depth = texture(depthBuffer, uv).x;
        vec3 ndc = vec3(uv, depth);
        
        //vec3 hitPos = unproject(ubo.invProjectionMatrix, ndc);
        
        // Optimized unproject
        vec2 ndcXY = uv * 2.0 - 1.0;
        float ndcZ = depth * 2.0 - 1.0;
        float resZ = I02 * ndcXY.x + I12 * ndcXY.y + I22 * ndcZ + I32;
        float resW = I03 * ndcXY.x + I13 * ndcXY.y + I23 * ndcZ + I33;
        float sceneZ = resZ / resW;

        // Hit test
        if (samplePos.z < sceneZ && samplePos.z > sceneZ - hitThickness)
        {
            float tLo = prevT;
            float tHi = t;

            // Binary search refinement
            for (uint j = 0; j < refineSamples; j++)
            {
                float tMid = 0.5 * (tLo + tHi);
                vec3 midPos = P + R * tMid;

                // Fast projection again
                float midClipW = midPos.z * P32;
                float midInvW = 1.0 / midClipW;
                
                vec2 midUV;
                midUV.x = (midPos.x * P00 + midPos.z * P20) * midInvW;
                midUV.y = (midPos.y * P11 + midPos.z * P21) * midInvW;
                midUV.xy = midUV.xy * 0.5 + 0.5;
                midUV.y = 1.0 - midUV.y;

                if (midUV.x < 0.0 || midUV.x > 1.0 || midUV.y < 0.0 || midUV.y > 1.0)
                {
                    tHi = tMid;
                    continue;
                }

                float midDepth = texture(depthBuffer, midUV).x;
                
                //vec3 midHitPos = unproject(ubo.invProjectionMatrix, vec3(midUV, midDepth));
                
                // Optimized unproject
                vec2 midNdcXY = midUV * 2.0 - 1.0;
                float midNdcZ = midDepth * 2.0 - 1.0;
                float midResZ = I02 * midNdcXY.x + I12 * midNdcXY.y + I22 * midNdcZ + I32;
                float midResW = I03 * midNdcXY.x + I13 * midNdcXY.y + I23 * midNdcZ + I33;
                float midHitZ = midResZ / midResW;

                if (midPos.z < midHitZ) tHi = tMid; else tLo = tMid;
            }

            // Final hit position
            float tFinal = tHi;
            vec3 finalPos = P + R * tFinal;
            
            float finalClipW = finalPos.z * P32;
            float finalInvW = 1.0 / finalClipW;
            
            vec2 finalUV;
            finalUV.x = (finalPos.x * P00 + finalPos.z * P20) * finalInvW;
            finalUV.y = (finalPos.y * P11 + finalPos.z * P21) * finalInvW;
            finalUV.xy = finalUV.xy * 0.5 + 0.5;
            finalUV.y = 1.0 - finalUV.y;

            // Fade out reflectionat edges
            vec2 edgeFactor = smoothstep(vec2(0.0), vec2(0.2), finalUV) * (1.0 - smoothstep(vec2(0.8), vec2(1.0), finalUV));
            float screenFade = edgeFactor.x * edgeFactor.y;
            float alpha = clamp(screenFade, 0.0, 1.0) * roughnessFactor;

            return vec4(texture(radianceBuffer, finalUV).rgb, alpha);
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
    
    vec3 wN = normalize(texture(normalBuffer, texCoords).rgb * 2.0 - 1.0);
    
    vec3 N = mat3(ubo.viewMatrix) * wN;
    vec3 E = normalize(eyePos);
    float NE = clamp(dot(N, E), 0.0, 1.0);
    
    vec4 roughnessMetallic = texture(roughnessMetallicBuffer, texCoords);
    float f0_scalar = roughnessMetallic.r;
    float roughness = roughnessMetallic.g;
    float metallic = roughnessMetallic.b;
    float shadingMask = roughnessMetallic.a;
    vec4 color = texture(colorBuffer, texCoords);
    vec3 baseColor = toLinear(color.rgb);
    
    vec2 xi = vec2(
        hash(texCoords + time),
        hash(texCoords * 1.1 + time)
    );
    vec3 H = importanceSampleGGX(xi, roughness, N);
    vec3 R = normalize(reflect(E, mix(N, H, roughness)));
    
    vec3 f0 = mix(vec3(f0_scalar), baseColor, metallic);
    vec3 F = clamp(fresnelRoughness(NE, f0, roughness), 0.0, 1.0);
    
    /*
    vec2 brdf = (bool(ubo.iparams[0]))?
        texture(brdfLUT, vec2(NE, roughness)).rg :
        vec2(1.0, 0.0);
    F = clamp(F * brdf.x + brdf.y, 0.0, 1.0);
    */
    
    vec4 reflection = sslr(eyePos, R, roughness);
    reflection.rgb *= F;
    
    // Temporal accumulation
    vec2 uvVelocity = texture(velocityBuffer, texCoords).xy;
    vec2 prevTexCoords = texCoords - uvVelocity;
    vec4 prevReflection = texture(prevReflectionBuffer, prevTexCoords);
    float velocityLength = length(uvVelocity);
    const float velocityFactor = clamp(velocityLength * velocitySensitivity, 0.0, 1.0);
    float alpha = mix(historyWeight, motionWeight, velocityFactor);

    vec4 accumulatedReflection = mix(prevReflection, reflection, alpha * shadingMask);
    
    outColor = accumulatedReflection;
}
