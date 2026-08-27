# Resources

This guide covers basic asset management and the resource caching system in Dagon.

Resources, also known as assets, are the data loaded by the game in run time from external files. These can be 3D models, textures, or any custom data the game depends on. Most assets use some widely-recongnized format, for example, textures are usually stored in standard image file formats (PNG, JPEG) or in specialized container formats (DDS, KTX).

Loading assets from disk and decoding them are huge performance bottlenecks, and the overhead of decoding different asset formats vary widely. Some formats are very GPU-friendly and can be used directly, with little to no pre-processing, but some are rather quirky to load. Dagon hides almost all complexity of the asset pipeline under the hood, providing great support for many kinds of asset formats. It also allows for efficient transcoding and caching to reduce subsequent loading times.

## Shader Modules

In Dagon 2, a shader module is an independent unit of compilation for a certain stage of the programmable pipeline. It can be a vertex module, fragment module, or a compute module. Shader modules are usually loaded from GLSL source files:

```d
ShaderModule vertexModule = New!ShaderModule(gpu, this);
vertexModule.create("filename.vert.glsl", "shaders/filename.vert.glsl",
    ShaderSourceType.File, ShaderLanguage.GLSL, PipelineStage.Vertex);
```

Internally, `ShaderModule` compiles the source to SPIR-V and caches it to disk for reuse. It is then recompiled only if the source file is newer than the SPIR-V file.

## Textures

TODO

## 3D Models

TODO
