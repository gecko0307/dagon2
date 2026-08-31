#version 460

/*
 * Subpixel Morphological Anti-Aliasing (edge detection pass).
 * SMAA implementation is based on the code by Jorge Jimenez,
 * Jose I. Echevarria, Belen Masia, Fernando Navarro and Diego Gutierrez.
 * https://github.com/iryoku/smaa
 * See license/SMAA.txt for details.
 */

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;

layout(location = 0) in vec2 texCoords;
layout(location = 1) in vec4 offset[3];

layout(location = 0) out vec4 outEdges;

void main()
{
    // Calculate lumas
    vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    float L = dot(texture(colorBuffer, texCoords).rgb, weights);
    float Lleft = dot(texture(colorBuffer, offset[0].xy).rgb, weights);
    float Ltop  = dot(texture(colorBuffer, offset[0].zw).rgb, weights);
    
    vec4 delta;
    delta.xy = abs(L - vec2(Lleft, Ltop));
    vec2 edges = step(vec2(0.1), delta.xy);
    
    // Discard if there is no edge
    if (dot(edges, vec2(1.0, 1.0)) == 0.0)
        discard;
    //if (edges.x == 0.0 && edges.y == 0.0)
    //    discard;
    
    // Calculate right and bottom deltas
    float Lright = dot(texture(colorBuffer, offset[1].xy).rgb, weights);
    float Lbottom = dot(texture(colorBuffer, offset[1].zw).rgb, weights);
    delta.zw = abs(L - vec2(Lright, Lbottom));
    
    // Calculate the maximum delta in the direct neighborhood
    vec2 maxDelta = max(delta.xy, delta.zw);
    maxDelta = max(maxDelta.xx, maxDelta.yy);

    // Calculate left-left and top-top deltas
    float Lleftleft = dot(texture(colorBuffer, offset[2].xy).rgb, weights);
    float Ltoptop = dot(texture(colorBuffer, offset[2].zw).rgb, weights);
    delta.zw = abs(vec2(Lleft, Ltop) - vec2(Lleftleft, Ltoptop));

    // Calculate the final maximum delta
    maxDelta = max(maxDelta.xy, delta.zw);

    /*
     * Each edge with a delta in luma of less than 50% of the maximum luma
     * surrounding this pixel is discarded. This allows to eliminate spurious
     * crossing edges, and is based on the fact that, if there is too much
     * contrast in a direction, that will hide contrast in the other
     * neighbors.
     * This is done after the discard intentionally as this situation doesn't
     * happen too frequently (but it's important to do as it prevents some 
     * edges from going undetected).
     */
    outEdges = vec4(edges * step(0.5 * maxDelta, delta.xy), 0.0, 1.0);
}
