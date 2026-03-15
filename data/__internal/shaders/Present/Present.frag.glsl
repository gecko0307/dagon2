#version 460

vec3 toGamma(vec3 v)
{
    return pow(v, vec3(1.0 / 2.2));
}

// Matrices for Rec. 2020 <> Rec. 709 color space conversion.
// Matrix provided in row-major order so it has been transposed.
// https://www.itu.int/pub/R-REP-BT.2407-2017
const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
    vec3(1.6605, -0.1246, -0.0182),
    vec3(-0.5876, 1.1329, -0.1006),
    vec3(-0.0728, -0.0083, 1.1187)
);

const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
    vec3(0.6274, 0.0691, 0.0164),
    vec3(0.3293, 0.9195, 0.0880),
    vec3(0.0433, 0.0113, 0.8956)
);

// AgX Tone Mapping implementation based on Filament, which in turn is based
// on Blender's implementation using Rec. 2020 primaries
// https://github.com/google/filament/pull/7236
// Inputs and outputs are encoded as Linear-sRGB.

#define AGX_LOOK_BASE 0
#define AGX_LOOK_PUNCHY 1

// https://iolite-engine.com/blog_posts/minimal_agx_implementation
// Mean error^2: 3.6705141e-06
vec3 agxDefaultContrastApprox(vec3 x)
{
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    return + 15.5 * x4 * x2
        - 40.14 * x4 * x
        + 31.96 * x4
        - 6.868 * x2 * x
        + 0.4298 * x2
        + 0.1191 * x
        - 0.00232;
}

vec3 agxLook(vec3 color, int look)
{
    if (look == AGX_LOOK_BASE)
        return color;

    // Rec. 2020 luminance coefficients
    const vec3 lw = vec3(0.2626983, 0.6780088, 0.0592929);

    float luma = dot(color, lw);

    vec3 offset = vec3(0.0);
    vec3 slope = vec3(1.0);
    vec3 power = vec3(1.0);
    float sat = 1.0;

    if (look == AGX_LOOK_PUNCHY)
    {
        slope = vec3(1.0);
        power = vec3(1.35, 1.35, 1.35);
        sat = 1.4;
    }

    // ASC CDL
    color = pow(color * slope + offset, power);

    return luma + sat * (color - luma);
}

vec3 tonemapAgX(vec3 color, int look)
{
    // AgX constants
    const mat3 AgXInsetMatrix = mat3(
        vec3(0.856627153315983, 0.137318972929847, 0.11189821299995),
        vec3(0.0951212405381588, 0.761241990602591, 0.0767994186031903),
        vec3(0.0482516061458583, 0.101439036467562, 0.811302368396859)
    );

    // explicit AgXOutsetMatrix generated from Filaments AgXOutsetMatrixInv
    const mat3 AgXOutsetMatrix = mat3(
        vec3(1.1271005818144368, -0.1413297634984383, -0.14132976349843826),
        vec3(-0.11060664309660323, 1.157823702216272, -0.11060664309660294),
        vec3(-0.016493938717834573, -0.016493938717834257, 1.2519364065950405)
    );

    // LOG2_MIN = -10.0
    // LOG2_MAX =  +6.5
    // MIDDLE_GRAY = 0.18
    const float AgxMinEv = -12.47393; // log2(pow(2, LOG2_MIN) * MIDDLE_GRAY)
    const float AgxMaxEv = 4.026069;  // log2(pow(2, LOG2_MAX) * MIDDLE_GRAY)

    color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
    color = AgXInsetMatrix * color;

    // Log2 encoding
    color = max(color, 1e-10); // avoid 0 or negative numbers for log2
    color = log2(color);
    color = (color - AgxMinEv) / (AgxMaxEv - AgxMinEv);
    color = clamp(color, 0.0, 1.0);

    // Apply sigmoid
    color = agxDefaultContrastApprox(color);

    // Apply AgX look
    color = agxLook(color, look);

    color = AgXOutsetMatrix * color;

    // Linearize
    color = pow(max(vec3(0.0), color), vec3(2.2));

    color = LINEAR_REC2020_TO_LINEAR_SRGB * color;

    // Gamut mapping. Simple clamp for now
    color = clamp(color, 0.0, 1.0);

    return color;
}

#define TONEMAPPER_NONE 0
#define TONEMAPPER_AGX_BASE 1
#define TONEMAPPER_AGX_PUNCHY 2

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    uint flags[4];
    vec4 hdrClampingParams;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

void main()
{
    vec4 inputColor = texture(colorBuffer, texCoords);
    vec3 outputColor;
    if (ubo.flags[0] == TONEMAPPER_NONE)
        outputColor = clamp(inputColor.rgb, ubo.hdrClampingParams.x, ubo.hdrClampingParams.y);
    else if (ubo.flags[0] == TONEMAPPER_AGX_BASE)
        outputColor = toGamma(tonemapAgX(inputColor.rgb, AGX_LOOK_BASE));
    else if (ubo.flags[0] == TONEMAPPER_AGX_PUNCHY)
        outputColor = toGamma(tonemapAgX(inputColor.rgb, AGX_LOOK_PUNCHY));
    outColor = vec4(outputColor, 1.0);
}
