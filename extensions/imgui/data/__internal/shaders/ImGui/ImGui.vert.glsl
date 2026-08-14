#version 450 core

layout(location = 0) in vec2 va_Pos;
layout(location = 1) in vec2 va_TexCoord;
layout(location = 2) in vec4 va_Color;

layout(set = 1, binding = 0) uniform UBO
{
    vec4 position;
    vec4 scaling;
} ubo;

layout(location = 0) out struct
{
    vec4 color;
    vec2 uv;
} Out;

void main()
{
    Out.color = va_Color;
    Out.uv = va_TexCoord;
    gl_Position = vec4(va_Pos * ubo.scaling.xy + ubo.position.xy, 0.0, 1.0);
    gl_Position.y *= -1.0;
}
