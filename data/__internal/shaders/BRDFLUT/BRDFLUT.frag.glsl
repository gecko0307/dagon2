#version 460

#define PI 3.141592653589793
const float PI2 = PI * 2.0;

float saturate(float x)
{
    return clamp(x, 0.0, 1.0);
}

vec3 importanceSampleGGX(vec2 Xi, float roughness, vec3 N)
{
    float a = roughness * roughness;
    
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

// Generates the i-th 2D Hammersley point out of N
vec2 hammersley(uint i, uint N) 
{
    // Radical inverse based on http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
    uint bits = (i << 16u) | (i >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    float rdi = float(bits) * 2.3283064365386963e-10;
    return vec2(float(i) / float(N), rdi);
}

float V_SmithGGXCorrelated(float NoV, float NoL, float a2)
{
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

const uint numSamples = 1024u;

vec2 integrateBRDF(float roughness, float NoV)
{
    vec3 N = vec3(0.0, 0.0, 1.0);
    vec3 V = vec3(sqrt(1.0 - NoV * NoV), 0.0, NoV);
    float a2 = pow(roughness, 4.0);

    float A = 0.0;
    float B = 0.0;

    for (uint i = 0; i < numSamples; i++)
    {
        vec2 Xi = hammersley(i, numSamples);
        vec3 H = importanceSampleGGX(Xi, roughness, N);
        vec3 L = normalize(2.0 * dot(V, H) * H - V);

        float NoL = saturate(L.z);
        float NoH = saturate(H.z);
        float VoH = saturate(dot(V, H));

        if (NoL > 0.0)
        {
            float V_pdf = V_SmithGGXCorrelated(NoV, NoL, a2) * VoH * NoL / NoH;
            float Fc = pow(1.0 - VoH, 5.0);
            A += (1.0 - Fc) * V_pdf;
            B += Fc * V_pdf;
        }
    }
    
    return 4.0 * vec2(A, B) / float(numSamples);
}

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 fragColor;

void main()
{
    float roughness = clamp(1.0 - (gl_FragCoord.y + 0.5) / ubo.resolution.y, 0.0, 1.0);
    float NoV = clamp((gl_FragCoord.x + 0.5) / ubo.resolution.x, 0.0, 1.0);
    
    NoV = clamp(NoV, 0.001, 0.999);
    roughness = clamp(roughness, 0.04, 0.999);
    
    vec2 res = integrateBRDF(roughness, NoV);
    fragColor = vec4(res.x, res.y, roughness, 1.0);
}
