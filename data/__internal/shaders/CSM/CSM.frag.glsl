#version 460

layout(location = 0) in vec2 texCoords;

//uniform float opacity;

layout(location = 0) out vec4 outColor;

void main()
{    
    //vec4 fragDiffuse = diffuse(texCoord);
    
    //if ((fragDiffuse.a * opacity) < 0.5)
    //    discard;
    
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
