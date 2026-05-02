#version 460

/*
 * Lens distortion effect based on the code by Jaume Sanchez
 * https://github.com/spite/Wagner
 */

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution;
    vec4 fparams; // scale, dispersion
    uvec4 iparams;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

float aspectRatio = ubo.resolution.x / ubo.resolution.y;
float scale = ubo.fparams.x;
float dispersion = ubo.fparams.y;
float k1 = ubo.fparams.z;
float k2 = ubo.fparams.w;

vec2 distortion(vec2 uv, float amt)
{
    if (ubo.iparams.x > 0)
    {
        /*
         * Brown-Conrady radial distortion with two coefficients (k1, k2)
         */
        // Shift to -1 to 1 range, adjust for aspect ratio
        vec2 p = uv * 2.0 - 1.0;
        p.x *= aspectRatio;
        
        // Calculate radius squared
        float r2 = p.x * p.x + p.y * p.y;
        
        // Apply radial distortion
        uv = p * (1.0 + k1 * r2 + k2 * r2 * r2);
        
        // Shift back to 0 to 1 range
        uv.x /= aspectRatio;
        uv = (uv + 1.0) * 0.5;
    }
    
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc);
    return uv + cc * dist * amt;
}

float sat(float t)
{
    return clamp(t, 0.0, 1.0);
}

float linterp(float t)
{
    return sat(1.0 - abs(2.0 * t - 1.0));
}

float remap(float t, float a, float b)
{
    return sat((t - a) / (b - a));
}

vec3 spectrumOffset(float t)
{
    vec3 ret;
    float lo = step(t, 0.5);
    float hi = 1.0 - lo;
    float w = linterp(remap(t, 1.0 / 6.0, 5.0 / 6.0));
    return vec3(lo, 1.0, hi) * vec3(1.0 - w, w, 1.0 - w);
}

const int numIterations = 12;
const float invNumIterations = 1.0 / float(numIterations);

void main()
{
    vec2 uv = texCoords * scale + (1.0 - scale) * 0.5;

    vec3 sumcol = vec3(0.0);
    vec3 sumw = vec3(0.0);
    
    for(int i = 0; i < numIterations; ++i)
    {
        float t = float(i) * invNumIterations;
        vec3 w = spectrumOffset(t);
        sumw += w;
        vec2 distUV = distortion(uv, 0.6 * dispersion * t);
        sumcol += w * texture(colorBuffer, distUV).rgb;
    }
    
    outColor = vec4(sumcol / sumw, 1.0);
}
