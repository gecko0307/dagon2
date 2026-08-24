#version 460

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D srcTex;
layout(set = 1, binding = 0) uniform writeonly image2D destTex;

layout(set = 2, binding = 0) uniform UniformBuffer
{
    vec4 srcSize;
    vec4 destSize;
} ubo;

void main()
{
    ivec2 destCoord = ivec2(gl_GlobalInvocationID.xy);

    if (destCoord.x >= ubo.destSize.x || destCoord.y >= ubo.destSize.y)
        return;

    vec2 uv = vec2(destCoord) / ubo.destSize.xy;
    vec4 color = texture(srcTex, uv);
    imageStore(destTex, destCoord, color);
}
