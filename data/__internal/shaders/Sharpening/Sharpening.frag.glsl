#version 460

float luminance(vec3 c)
{
    return dot(c, vec3(0.299, 0.587, 0.114));
}

layout(set = 2, binding = 0) uniform sampler2D colorBuffer;

layout(set = 3, binding = 0) uniform UniformBuffer
{
    vec4 viewSize;
} ubo;

layout(location = 0) in vec2 texCoords;

layout(location = 0) out vec4 outColor;

const float sharpening = 0.5; // 0.0 – 1.0

void main()
{
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 viewSize = ubo.viewSize.xy;

    vec2 t = 1.0 / viewSize;

    // 3x3 neighborhood
    vec3 a = texture(colorBuffer, texCoords + vec2(-t.x, -t.y)).rgb;
    vec3 b = texture(colorBuffer, texCoords + vec2( 0.0, -t.y)).rgb;
    vec3 c = texture(colorBuffer, texCoords + vec2( t.x, -t.y)).rgb;

    vec3 d = texture(colorBuffer, texCoords + vec2(-t.x,  0.0)).rgb;
    vec3 e = texture(colorBuffer, texCoords).rgb;
    vec3 f = texture(colorBuffer, texCoords + vec2( t.x,  0.0)).rgb;

    vec3 g = texture(colorBuffer, texCoords + vec2(-t.x,  t.y)).rgb;
    vec3 h = texture(colorBuffer, texCoords + vec2( 0.0,  t.y)).rgb;
    vec3 i = texture(colorBuffer, texCoords + vec2( t.x,  t.y)).rgb;

    float la = luminance(a);
    float lb = luminance(b);
    float lc = luminance(c);
    float ld = luminance(d);
    float le = luminance(e);
    float lf = luminance(f);
    float lg = luminance(g);
    float lh = luminance(h);
    float li = luminance(i);

    float mn = min(le, min(min(lb, ld), min(lf, lh)));
    float mx = max(le, max(max(lb, ld), max(lf, lh)));

    float contrast = mx - mn;
    float amp = clamp(contrast > 0.0 ? (min(mn, 1.0 - mx) / mx) : 0.0, 0.0, 1.0);
    amp = sqrt(amp);

    float peak = mix(8.0, 5.0, sharpening);
    float weight = -amp / peak;

    vec3 sharpened = (b + d + f + h) * weight + e;

    float norm = 1.0 + 4.0 * weight;
    sharpened /= norm;

    outColor = vec4(max(vec3(0.0), sharpened), 1.0);
}
