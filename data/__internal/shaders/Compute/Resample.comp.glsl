#version 460

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D srcTex;
layout(set = 1, binding = 0) uniform writeonly image2D destTex;

layout(set = 2, binding = 0) uniform UniformBuffer
{
    vec4 srcSize;  // x, y - размер исходной текстуры
    vec4 destSize; // x, y - размер выходной текстуры
    ivec4 config;  // x: 0 - горизонтальный проход, 1 - вертикальный проход
                   // y: поднесущий радиус Ланцоша (обычно 2 или 3)
} ubo;

const float PI = 3.14159265359;

// Математическая функция Ланцоша (Lanczos Kernel)
float lanczos(float x, float a)
{
    if (x == 0.0) return 1.0;
    if (x <= -a || x >= a) return 0.0;
    float pi_x = x * PI;
    return (a * sin(pi_x) * sin(pi_x / a)) / (pi_x * pi_x);
}

void main()
{
    ivec2 destCoord = ivec2(gl_GlobalInvocationID.xy);
    if (destCoord.x >= ubo.destSize.x || destCoord.y >= ubo.destSize.y)
        return;

    bool isVertical = (ubo.config.x == 1);
    float a = float(ubo.config.y); // Радиус Ланцоша (Lanczos-2 или Lanczos-3)

    // Вычисляем шаг масштабирования
    vec2 scale = ubo.srcSize.xy / ubo.destSize.xy;
    float currentScale = isVertical ? scale.y : scale.x;

    // Расширяем радиус окна фильтрации, если мы уменьшаем картинку (Downscaling)
    float filterSupport = a;
    float filterScale = 1.0;
    if (currentScale > 1.0)
    {
        filterSupport = a * currentScale;
        filterScale = 1.0 / currentScale;
    }

    // Центр выборки в координатах исходной текстуры
    float centerPos = (float(isVertical ? destCoord.y : destCoord.x) + 0.5) * currentScale;

    // Границы сканирования окна (по пикселям исходной текстуры)
    int startIdx = int(floor(centerPos - filterSupport));
    int endIdx   = int(ceil(centerPos + filterSupport));

    int maxCoord = isVertical ? int(ubo.srcSize.y) - 1 : int(ubo.srcSize.x) - 1;

    vec4 colorSum = vec4(0.0);
    float weightSum = 0.0;

    // Сканируем динамическое окно
    for (int i = startIdx; i <= endIdx; ++i)
    {
        // Вычисляем расстояние от центра текущего пикселя до центра фильтра
        float samplePos = float(i) + 0.5;
        float diff = samplePos - centerPos;

        // Вычисляем вес Ланцоша с учетом масштабирования окна
        float weight = lanczos(diff * filterScale, a);

        if (weight > 0.0001)
        {
            // Безопасно ограничиваем координату (Clamp to Edge)
            int clampedIdx = clamp(i, 0, maxCoord);
            ivec2 texelCoord = isVertical ? ivec2(destCoord.x, clampedIdx) : ivec2(clampedIdx, destCoord.y);

            // Читаем пиксель напрямую
            vec4 texel = texelFetch(srcTex, texelCoord, 0);

            colorSum += texel * weight;
            weightSum += weight;
        }
    }

    // Нормализуем цвет, чтобы не было изменения общей яркости
    vec4 finalColor = colorSum / max(weightSum, 0.0001);

    imageStore(destTex, destCoord, finalColor);
}

/*
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
*/