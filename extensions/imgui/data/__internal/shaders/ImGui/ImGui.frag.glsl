#version 450 core
layout(location = 0) out vec4 fColor;

layout(set = 2, binding = 0) uniform sampler2D sTexture;

layout(std140, location = 0) in struct
{
    vec4 color;
    vec4 uv;
} In;

void main()
{
    fColor = In.color * texture(sTexture, In.uv.st);
}
