#version 460

#define PI 3.14159265359
const float PI2 = PI * 2.0;
const float EPSILON = 0.00001;

const uint numSamples = 1024u;
const float invNumSamples = 1.0 / float(numSamples);

// Generates the i-th 2D Hammersley point out of N
vec2 hammersley(uint i) 
{
    // Radical inverse based on http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
    uint bits = (i << 16u) | (i >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    float rdi = float(bits) * 2.3283064365386963e-10;
    return vec2(float(i) * invNumSamples, rdi);
}

// Uniformly sample point on a hemisphere
vec3 sampleHemisphere(float u1, float u2)
{
    const float u1p = sqrt(max(0.0, 1.0 - u1 * u1));
    return vec3(cos(PI2 * u2) * u1p, sin(PI2 * u2) * u1p, u1);
}

vec3 getDirectionForCubemapFace(uint faceIndex, vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    vec3 dir;
    if (faceIndex == 0)      dir = normalize(vec3(1.0,   -uv.y, -uv.x)); // +X
    else if (faceIndex == 1) dir = normalize(vec3(-1.0,  -uv.y,  uv.x)); // -X
    else if (faceIndex == 2) dir = normalize(vec3(uv.x,   1.0,   uv.y)); // +Y
    else if (faceIndex == 3) dir = normalize(vec3(uv.x,  -1.0,  -uv.y)); // -Y
    else if (faceIndex == 4) dir = normalize(vec3(uv.x,  -uv.y,  1.0));  // +Z
    else if (faceIndex == 5) dir = normalize(vec3(-uv.x, -uv.y, -1.0));  // -Z
    return dir;
}

// Convert point from tangent/shading space to world space.
vec3 tangentToWorld(const vec3 v, const vec3 N, const vec3 S, const vec3 T)
{
    return S * v.x + T * v.y + N * v.z;
}

layout(set = 2, binding = 0) uniform samplerCube inputCubemap;
layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
    uvec4 iparams;
} ubo;

uint cubemapFaceIndex = ubo.iparams[0];

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 fragColor;

const float inputThreshold = 10.0f;
const float inputScale = 1.0f;

void main()
{
    vec3 N = getDirectionForCubemapFace(cubemapFaceIndex, texCoords);
    vec3 S, T;
    T = cross(N, vec3(0.0, 1.0, 0.0));
    T = mix(cross(N, vec3(1.0, 0.0, 0.0)), T, step(EPSILON, dot(T, T)));
    T = normalize(T);
    S = normalize(cross(N, T));

    vec3 irradiance = vec3(0);
    for (uint i = 0; i < numSamples; ++i)
    {
        vec2 u  = hammersley(i);
        vec3 Li = tangentToWorld(sampleHemisphere(u.x, u.y), N, S, T);
        float cosTheta = max(0.0, dot(Li, N));
        vec3 inputColor = clamp(textureLod(inputCubemap, Li, 0).rgb, vec3(0.0), vec3(inputThreshold)) * inputScale;
        irradiance += 2.0 * inputColor * cosTheta;
    }
    irradiance /= vec3(numSamples);

    fragColor = vec4(irradiance, 1.0);
}
