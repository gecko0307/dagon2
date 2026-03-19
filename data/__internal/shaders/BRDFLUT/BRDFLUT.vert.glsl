#version 460

layout(location = 0) in vec2 va_vertex;
layout(location = 1) in vec2 va_texcoord;

layout(location = 0) out vec2 texCoords;

void main()
{
    texCoords = va_texcoord;
    vec2 clipVertex = va_vertex * 2.0 - 1.0;
    clipVertex.y = -clipVertex.y;
    gl_Position = vec4(clipVertex, 0.0, 1.0);
}
