#version 460

/*
 * SMAA implementation is based on code by Jorge Jimenez, Jose I. Echevarria,
 * Belen Masia, Fernando Navarro and Diego Gutierrez.
 */

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;
layout(set = 2, binding = 1) uniform sampler2D blendingWeightsBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 resolution; // [1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight]
} ubo;

layout(location = 0) in vec2 texCoords;
layout(location = 1) in vec4 offset[2];

layout(location = 0) out vec4 outColor;

vec4 smaaNeighborhoodBlending(vec2 texcoord, vec4 offset[2], sampler2D colorTex, sampler2D blendTex)
{
    // Fetch the blending weights for current pixel
    vec4 a;
    a.xz = texture(blendTex, texcoord).xz;
    a.y = texture(blendTex, offset[1].zw).g;
    a.w = texture(blendTex, offset[1].xy).a;

    // Is there any blending weight with a value greater than 0.0?
    if (dot(a, vec4(1.0, 1.0, 1.0, 1.0)) < 1e-5)
    {
        return textureLod(colorTex, texcoord, 0.0);
    }
    else
    {
        vec4 color = vec4(0.0, 0.0, 0.0, 0.0);

        // Up to 4 lines can be crossing a pixel (one through each edge). We
        // favor blending by choosing the line with the maximum weight for each direction
        vec2 offset;
        offset.x = a.a > a.b? a.a : -a.b; // left vs. right 
        offset.y = a.g > a.r? a.g : -a.r; // top vs. bottom

        // Then we go in the direction that has the maximum weight
        if (abs(offset.x) > abs(offset.y)) // horizontal vs. vertical
            offset.y = 0.0;
        else
            offset.x = 0.0;
        
        // Fetch the opposite color and lerp by hand
        vec4 C = textureLod(colorTex, texcoord, 0.0);
        texcoord += sign(offset) * ubo.resolution.xy;
        vec4 Cop = textureLod(colorTex, texcoord, 0.0);
        float s = abs(offset.x) > abs(offset.y)? abs(offset.x) : abs(offset.y);
        return mix(C, Cop, s);
    }
}

void main()
{
    vec4 outputColor = smaaNeighborhoodBlending(texCoords, offset, colorBuffer, blendingWeightsBuffer);
    outColor = vec4(pow(outputColor.rgb, vec3(2.2)).rgb, 1.0);
}
