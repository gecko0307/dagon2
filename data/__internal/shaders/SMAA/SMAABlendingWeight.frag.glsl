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
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / vec2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
 
layout(set = 2, binding = 1) uniform sampler2D edgeTex;
layout(set = 2, binding = 2) uniform sampler2D areaTex;   // Precomputed Area LUT
layout(set = 2, binding = 3) uniform sampler2D searchTex; // Precomputed Search LUT

layout(location = 0) in vec2 texCoords;
layout(location = 1) in vec2 pixCoords;
layout(location = 2) in vec4 offset[3];

layout(location = 0) out vec4 outWeights;

layout(set = 1, binding = 0) uniform UniformBuffer
{
    vec4 resolution; // [1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight]
} ubo;

float smaaSearchLength(sampler2D searchTex, vec2 e, float bias, float scale)
{
    e.r = bias + e.r * scale;
    return 255.0 * textureLod(searchTex, e, 0.0).r;
}

float smaaSearchXLeft(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(0.0, 1.0);
    while (texcoord.x > end && e.g > 0.8281 && e.r == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord -= vec2(2.0, 0.0) * ubo.resolution.xy;
    }

    texcoord.x += 0.25 * ubo.resolution.x;
    texcoord.x += ubo.resolution.x;
    texcoord.x += 2.0 * ubo.resolution.x;
    texcoord.x -= ubo.resolution.x * smaaSearchLength(searchTex, e, 0.0, 0.5);
    return texcoord.x;
}

float smaaSearchXRight(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(0.0, 1.0);
    while (texcoord.x < end && e.g > 0.8281 && e.r == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord += vec2(2.0, 0.0) * ubo.resolution.xy;
    }

    texcoord.x -= 0.25 * ubo.resolution.x;
    texcoord.x -= ubo.resolution.x;
    texcoord.x -= 2.0 * ubo.resolution.x;
    texcoord.x += ubo.resolution.x * smaaSearchLength(searchTex, e, 0.5, 0.5);
    return texcoord.x;
}

float smaaSearchYUp(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(1.0, 0.0);
    while (texcoord.y > end && e.r > 0.8281 && e.g == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord -= vec2(0.0, 2.0) * ubo.resolution.xy;
    }

    texcoord.y += 0.25 * ubo.resolution.y;
    texcoord.y += ubo.resolution.y;
    texcoord.y += 2.0 * ubo.resolution.y;
    texcoord.y -= ubo.resolution.y * smaaSearchLength(searchTex, e.gr, 0.0, 0.5);
    return texcoord.y;
}

float smaaSearchYDown(sampler2D edgesTex, sampler2D searchTex, vec2 texcoord, float end)
{
    vec2 e = vec2(1.0, 0.0);
    while (texcoord.y < end && e.r > 0.8281 && e.g == 0.0)
    {
        e = textureLod(edgesTex, texcoord, 0.0).rg;
        texcoord += vec2(0.0, 2.0) * ubo.resolution.xy;
    }
    
    texcoord.y -= 0.25 * ubo.resolution.y;
    texcoord.y -= ubo.resolution.y;
    texcoord.y -= 2.0 * ubo.resolution.y;
    texcoord.y += ubo.resolution.y * smaaSearchLength(searchTex, e.gr, 0.5, 0.5);
    return texcoord.y;
}

vec2 smaaArea(sampler2D areaTex, vec2 dist, float e1, float e2, float offset)
{
    vec2 texcoord = float(SMAA_AREATEX_MAX_DISTANCE) * round(4.0 * vec2(e1, e2)) + dist;
    texcoord = SMAA_AREATEX_PIXEL_SIZE * texcoord + (0.5 * SMAA_AREATEX_PIXEL_SIZE);
    texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;
    return textureLod(areaTex, texcoord, 0.0).ra;
}

void smaaDetectHorizontalCornerPattern(sampler2D edgesTex, inout vec2 weights, vec2 texcoord, vec2 d)
{
    /*
    // TODO
    #if SMAA_CORNER_ROUNDING < 100 || SMAA_FORCE_CORNER_DETECTION == 1
    float4 coords = SMAAMad(float4(d.x, 0.0, d.y, 0.0),
                            SMAA_PIXEL_SIZE.xyxy, texcoord.xyxy);
    float2 e;
    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(0.0,  1.0)).r;
    bool left = abs(d.x) < abs(d.y);
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(0.0, -2.0)).r;
    if (left) weights *= SMAASaturate(float(SMAA_CORNER_ROUNDING) / 100.0 + 1.0 - e);

    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(1.0,  1.0)).r;
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(1.0, -2.0)).r;
    if (!left) weights *= SMAASaturate(float(SMAA_CORNER_ROUNDING) / 100.0 + 1.0 - e);
    #endif
    */
}

void smaaDetectVerticalCornerPattern(sampler2D edgesTex, inout vec2 weights, vec2 texcoord, vec2 d)
{
    /*
    // TODO
    #if SMAA_CORNER_ROUNDING < 100 || SMAA_FORCE_CORNER_DETECTION == 1
    float4 coords = SMAAMad(float4(0.0, d.x, 0.0, d.y),
                            SMAA_PIXEL_SIZE.xyxy, texcoord.xyxy);
    float2 e;
    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2( 1.0, 0.0)).g;
    bool left = abs(d.x) < abs(d.y);
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-2.0, 0.0)).g;
    if (left) weights *= SMAASaturate(float(SMAA_CORNER_ROUNDING) / 100.0 + 1.0 - e);

    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1.0, 1.0)).g;
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(-2.0, 1.0)).g;
    if (!left) weights *= SMAASaturate(float(SMAA_CORNER_ROUNDING) / 100.0 + 1.0 - e);
    #endif
    */
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

    vec2 e = texture(edgesTex, texcoord).rg;

    if (e.g > 0.0)
    {
        // Edge at north
        
        /*
        // TODO
        #if SMAA_MAX_SEARCH_STEPS_DIAG > 0 || SMAA_FORCE_DIAGONAL_DETECTION == 1
        // Diagonals have both north and west edges, so searching for them in
        // one of the boundaries is enough.
        weights.rg = SMAACalculateDiagWeights(edgesTex, areaTex, texcoord, e, subsampleIndices);

        // We give priority to diagonals, so if we find a diagonal we skip 
        // horizontal/vertical processing.
        if (dot(weights.rg, vec2(1.0, 1.0)) == 0.0) {
        #endif
        */

        vec2 d;

        // Find the distance to the left
        vec2 coords;
        coords.x = smaaSearchXLeft(edgesTex, searchTex, offset[0].xy, offset[2].x);
        coords.y = offset[1].y;
        d.x = coords.x;

        // Now fetch the left crossing edges, two at a time using bilinear
        // filtering. Sampling at -0.25 (see @CROSSING_OFFSET) enables to
        // discern what value each edge has
        float e1 = textureLod(edgesTex, coords, 0.0).r;

        // Find the distance to the right
        coords.x = smaaSearchXRight(edgesTex, searchTex, offset[0].zw, offset[2].y);
        d.y = coords.x;

        // We want the distances to be in pixel units (doing this here allow to
        // better interleave arithmetic and memory accesses)
        d = d / ubo.resolution.x - pixcoord.x;

        // smaaArea below needs a sqrt, as the areas texture is compressed quadratically
        vec2 sqrt_d = sqrt(abs(d));

        // Fetch the right crossing edges
        float e2 = textureLodOffset(edgesTex, coords, 0.0, ivec2(1, 0)).r;

        // Ok, we know how this pattern looks like, now it is time for getting the actual area
        weights.rg = smaaArea(areaTex, sqrt_d, e1, e2, float(subsampleIndices.y));

        // Fix corners
        smaaDetectHorizontalCornerPattern(edgesTex, weights.rg, texcoord, d);

        /*
        // TODO
        #if SMAA_MAX_SEARCH_STEPS_DIAG > 0 || SMAA_FORCE_DIAGONAL_DETECTION == 1
        } else
            e.r = 0.0; // Skip vertical processing.
        #endif
        */
    }

    if (e.r > 0.0)
    {
        // Edge at west
        vec2 d;

        // Find the distance to the top
        vec2 coords;
        coords.y = smaaSearchYUp(edgesTex, searchTex, offset[1].xy, offset[2].z);
        coords.x = offset[0].x;
        d.x = coords.y;

        // Fetch the top crossing edges
        float e1 = textureLod(edgesTex, coords, 0.0).g;

        // Find the distance to the bottom:
        coords.y = smaaSearchYDown(edgesTex, searchTex, offset[1].zw, offset[2].w);
        d.y = coords.y;

        // We want the distances to be in pixel units
        d = d / ubo.resolution.y - pixcoord.y;

        // smaaArea below needs a sqrt, as the areas texture is compressed quadratically
        vec2 sqrt_d = sqrt(abs(d));

        // Fetch the bottom crossing edges
        float e2 = textureLodOffset(edgesTex, coords, 0.0, int2(0, 1)).g;

        // Get the area for this direction
        weights.ba = smaaArea(areaTex, sqrt_d, e1, e2, float(subsampleIndices.x));

        // Fix corners
        smaaDetectVerticalCornerPattern(edgesTex, weights.ba, texcoord, d);
    }

    return weights;
}

void main()
{
    outWeights = smaaBlendingWeights(texCoords, pixCoords, offset, edgeTex, areaTex, searchTex, ivec4(0));
}
