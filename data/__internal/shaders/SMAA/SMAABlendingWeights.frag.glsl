#version 460

/*
 * SMAA implementation is based on code by Jorge Jimenez, Jose I. Echevarria,
 * Belen Masia, Fernando Navarro and Diego Gutierrez.
 */

#define SMAA_MAX_SEARCH_STEPS_DIAG 8
//#define SMAA_FORCE_DIAGONAL_DETECTION 1

#define SMAA_CORNER_ROUNDING 25
//#define SMAA_FORCE_CORNER_DETECTION

#define SMAA_AREATEX_MAX_DISTANCE 16
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / vec2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE vec2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE vec2(64.0, 16.0)
 
layout(set = 2, binding = 0) uniform sampler2D edgeTex;
layout(set = 2, binding = 1) uniform sampler2D areaTex;
layout(set = 2, binding = 2) uniform sampler2D searchTex;

layout(location = 0) in vec2 texCoords;
layout(location = 1) in vec2 pixCoords;
layout(location = 2) in vec4 offset[3];

layout(location = 0) out vec4 outWeights;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution; // [1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight]
} ubo;

// Convenient macros to access metrics
#define FRAME_INV_SIZE ubo.resolution.xy
#define FRAME_INV_WIDTH ubo.resolution.x
#define FRAME_INV_HEIGHT ubo.resolution.y
#define FRAME_SIZE ubo.resolution.zw
#define FRAME_WIDTH ubo.resolution.z
#define FRAME_HEIGHT ubo.resolution.w

float smaaSearchLength(sampler2D searchTex, vec2 e, float offset)
{
    vec2 scale = SMAA_SEARCHTEX_SIZE * vec2(0.5, -1.0);
    vec2 bias = SMAA_SEARCHTEX_SIZE * vec2(offset, 1.0);
    scale += vec2(-1.0,  1.0);
    bias  += vec2( 0.5, -0.5);
    scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
    bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
    return textureLod(searchTex, fma(scale, e, bias), 0.0).r;
}

float smaaSearchXLeft(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(0.0, 1.0);
    while (texcoord.x > end && e.g > 0.8281 && e.r == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord -= vec2(2.0, 0.0) * FRAME_INV_SIZE;
    }
    float offset = fma(-(255.0 / 127.0), smaaSearchLength(searchTex, e, 0.0), 3.25);
    return fma(FRAME_INV_WIDTH, offset, texcoord.x);
}

float smaaSearchXRight(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(0.0, 1.0);
    while (texcoord.x < end && e.g > 0.8281 && e.r == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord += vec2(2.0, 0.0) * FRAME_INV_SIZE;
    }
    float offset = fma(-(255.0 / 127.0), smaaSearchLength(searchTex, e, 0.5), 3.25);
    return fma(-FRAME_INV_WIDTH, offset, texcoord.x);
}

float smaaSearchYUp(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(1.0, 0.0);
    while (texcoord.y > end && e.r > 0.8281 && e.g == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord -= vec2(0.0, 2.0) * FRAME_INV_SIZE;
    }
    float offset = fma(-(255.0 / 127.0), smaaSearchLength(searchTex, e.gr, 0.0), 3.25);
    return fma(FRAME_INV_HEIGHT, offset, texcoord.y);
}

float smaaSearchYDown(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(1.0, 0.0);
    while (texcoord.y < end && e.r > 0.8281 && e.g == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord += vec2(0.0, 2.0) * FRAME_INV_SIZE;
    }
    float offset = fma(-(255.0 / 127.0), smaaSearchLength(searchTex, e.gr, 0.5), 3.25);
    return fma(-FRAME_INV_HEIGHT, offset, texcoord.y);
}

vec2 smaaArea(sampler2D areaTex, vec2 dist, float e1, float e2, float offset)
{
    vec2 texcoord = float(SMAA_AREATEX_MAX_DISTANCE) * round(4.0 * vec2(e1, e2)) + dist;
    texcoord = SMAA_AREATEX_PIXEL_SIZE * texcoord + (0.5 * SMAA_AREATEX_PIXEL_SIZE);
    texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;
    return textureLod(areaTex, texcoord, 0.0).rg;
}

vec4 smaaBlendingWeights(
    vec2 texcoord,
    vec2 pixcoord,
    vec4 offset[3],
    sampler2D edgesTex, 
    sampler2D areaTex, 
    sampler2D searchTex,
    ivec4 subsampleIndices) // Pass zero for SMAA 1x
{
    vec4 weights = vec4(0.0, 0.0, 0.0, 0.0);

    vec2 e = textureLod(edgesTex, texcoord, 0.0).rg;

    if (e.g > 0.0)
    {
        vec2 d;

        vec2 coords;
        coords.x = smaaSearchXLeft(edgesTex, searchTex, offset[0].xy, offset[2].x);
        coords.y = offset[1].y;
        d.x = coords.x;

        float e1 = textureLod(edgesTex, coords, 0.0).r;
        coords.x = smaaSearchXRight(edgesTex, searchTex, offset[0].zw, offset[2].y);
        d.y = coords.x;
        
        d = abs(round(d * FRAME_WIDTH - pixcoord.x));
        vec2 sqrt_d = sqrt(d);
        float e2 = textureLodOffset(edgesTex, coords, 0.0, ivec2(1, 0)).r;
        weights.rg = smaaArea(areaTex, sqrt_d, e1, e2, float(subsampleIndices.y));
    }

    if (e.r > 0.0)
    {
        vec2 d;

        vec2 coords;
        coords.y = smaaSearchYUp(edgesTex, searchTex, offset[1].xy, offset[2].z);
        coords.x = offset[0].x;
        d.x = coords.y;

        float e1 = textureLod(edgesTex, coords, 0.0).g;
        coords.y = smaaSearchYDown(edgesTex, searchTex, offset[1].zw, offset[2].w);
        d.y = coords.y;
        
        d = abs(round(d * FRAME_HEIGHT - pixcoord.y));
        vec2 sqrt_d = sqrt(d);
        float e2 = textureLodOffset(edgesTex, coords, 0.0, ivec2(0, 1)).g;
        weights.ba = smaaArea(areaTex, sqrt_d, e1, e2, float(subsampleIndices.x));
    }

    return weights;
}

void main()
{
    outWeights = smaaBlendingWeights(texCoords, pixCoords, offset, edgeTex, areaTex, searchTex, ivec4(0));
}
