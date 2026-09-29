# Shaders

Shader is a program for GPU. The term "shader" is somewhat vague because nowadays it is not necessarily used to calculate shading of 3D surfaces (although that's still major usage scenario). It is simply a program that is executed in parallel over an array, be it an array of vertices (in case of a vertex shader), a screen-space pixel triangle (in case of a fragment shader), or completely arbitrary data (in case of a compute shader).

## Shaders in the Context of Rendering

In a game renderer, fragment shaders are used to sample textures, evaluate BRDFs, compute shadowing, environmental effects and indirect lighting, and apply post-processing filters. Deferred renderer is a complex software utilizing many small, specialized shaders for different tasks (in contrast to forward renderer which usually uses a few large, branched "ubershaders"). Breaking rendering to a chain of passes means more control over the process and more sophisticated lighting techniques, but in pre-Vulkan era switching shaders considered expensive operation; the tradeoff between overhead for switching shaders and the versatility of the renderer was the main consern in real-time rendering. Now, thanks to immutable pipelines, this is a lot less of an issue, and multi-pass rendering is a de-facto industry standard.

## GLSL and SPIR-V

Dagon uses GLSL 4.60 as a primary shading language, but human-readable GLSL shaders cannot be used with Vulkan directly, requiring compilation to a low-level intermediate representation known as SPIR-V (Standard Portable Intermediate Representation for Vulkan). Many engines do this offline, but Dagon pre-compiles shaders at runtime, leveraging GLSLang library, and caches SPIR-V modules to disk for reuse. This means the very first run of the game takes some time, but at subsequent runs shaders are loaded very fast.

Most of the shaders utilized by Dagon's renderer are managed fully automatically. If you write your own shaders, you still can use the shader cache, or you can load them fully by yourself bypassing built-in mechanisms, and provide GLSL strings for vertex and fragment programs. You can even use a third-party shader toolchain and provide compiled SPIR-V modules instead of GLSL source code. In all cases, it is important to follow Dagon's pipeline conventions:

- Use GLSL version 4.5 or 4.6 (`#version 450` or `#version 460`)
- Use uniform binding layout mandated by SDL GPU. All four descriptor sets are strictly assigned:
  - **Set 0** — vertex-stage textures/samplers and SSBOs
  - **Set 1** — vertex-stage UBOs
  - **Set 2** — fragment-stage textures/samplers and SSBOs
  - **Set 3** — fragment-stage UBOs.
- All UBOs should use std140 memory layout:
  - Scalar fields (`float`, `int`, `uint`, `bool`): should be aligned to 4 bytes
  - 2-component vectors (`vec2`, `ivec2`): should be aligned to 8 bytes
  - 3-component and 4-component vectors (`vec3`, `ivec3`, `vec4`, `ivec4`): should be aligned to 16 bytes
  - Matrices are treated as an array of column vectors, where each column is aligned as a 4-component vector (16 bytes). Effectively, any matrix should be passed as an upper-left submatrix of `mat4`. Unused elements, if any, should be zero-initialized, just in case
  - Arrays of scalars/vectors: each element has a 16-byte stride, meaning every element occupies a 16-byte slot regardless of whether it is a scalar, vec2, vec3, or vec4. Unused bytes, if any, should be zero-initialized, just in case
  - Structures: base alignment is calculated as the maximum alignment of the structure's members, after which the result is rounded up to 16 bytes. Nested structures should follow the same alignment rules. Padding bytes do not carry meaningful data and may contain arbitrary values.

These conventions allow Dagon to bind resources predictably without requiring shaders to declare arbitrary descriptor layouts.

Dagon includes a compile-time std140 checker for types used as UBOs. The checker is enabled by default to prevent accidental mismatches between CPU-side structures and GLSL uniform blocks. However, there may be cases where the checker cannot determine compliance automatically. If you are certain that a structure follows the std140 layout rules, you can bypass the check by applying the `@Std140Guaranteed` attribute:

```d
@Std140Guaranteed
struct YourStructure
{
    // data
}
```

This, however, is not something to be abused. Use this attribute with care; any mismatches become the programmer's responsibility.

## Custom Shaders

All shaders should inherit from the base `Shader` class. Instead of a `ShaderProgram` from Dagon 1.0, `ShaderModule` objects are used. They should be assigned to `Shader.vertexModule` and `Shader.fragmentModule` upon construction.

Uniform buffers and other shader parameters are bound in the overridden `bindParameters` method. The method receives the current `GraphicsState`, which provides access to the render pass and associated context.

Example:

```d
class CustomShader: Shader
{
   protected:
    CustomShaderVertexUniformBuffer vsUBO;
    CustomShaderFragmentUniformBuffer fsUBO;
    
   public:
    this(GPU gpu, Owner owner)
    {
        super(gpu, owner);
        
        vertexModule = New!ShaderModule(gpu, this);
        vertexModule.create("CustomShader.vert.glsl", "shaders/CustomShader.vert.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
        
        fragmentModule = New!ShaderModule(gpu, this);
        fragmentModule.create("CustomShader.frag.glsl", "shaders/CustomShader.frag.glsl",
            ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Fragment);
        
        if (!vertexModule.valid || !fragmentModule.valid)
        {
            exitWithError("Failed to create CustomShader");
        }
        
        // Initialize vsUBO and fsUBO:
        // vsUBO.someField = someValue;
        // fsUBO.someField = someValue;
    }
    
    override void bindParameters(GraphicsState* state)
    {
        auto pass = state.pass;
        auto entity = state.entity;
        auto material = state.material;
        
        // Update vsUBO and fsUBO...
        
        pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
        pass.bindUniformBuffer(PipelineStage.Fragment, 0, &fsUBO);
    }
}
```

The binding indices must match the bindings declared in the GLSL shader. For example:

```glsl
layout(std140, set = 1, binding = 0) uniform VertexUniforms
{
    // ...
};
```

corresponds to:

```d
pass.bindUniformBuffer(PipelineStage.Vertex, 0, &vsUBO);
```

Textures are bound to the pass in a similar way:

```d
pass.bindTexture(PipelineStage.Fragment, 0, material.baseColorTexture);
```

The above corresponds to the following definition in the shader:

```glsl
layout(set = 2, binding = 0) uniform sampler2D baseColorTexture;
```
