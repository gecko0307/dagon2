# Shaders
Shader is a program for GPU. The term "shader" is somewhat vague because nowadays it is not necessarily used to calculate shading of 3D surfaces (although that's still major usage scenario). It is simply a program that is executed in parallel over an array, be it an array of vertices (in case of a vertex shader), a screen-space pixel triangle (in case of a fragment shader), or completely arbitrary data (in case of a compute shader).

## Shaders in the Context of Rendering
In a game renderer, fragment shaders are used to sample textures, evaluate BRDFs, compute shadowing, environmental effects and indirect lighting, and apply post-processing filters. Deferred renderer is a complex software utilizing many small, specialized shaders for different tasks (in contrast to forward renderer which usually uses a few large, branched "ubershaders"). Breaking rendering to a chain of passes means more control over the process and more sophisticated lighting techniques, but in pre-Vulkan era switching shaders considered expensive operation; the tradeoff between overhead for switching shaders and the versatility of the renderer was the main consern in real-time rendering. Now, thanks to immutable pipelines, this is a lot less of an issue, and multi-pass rendering is a de-facto industry standard.

## GLSL and SPIR-V
Dagon uses GLSL 4.60 as a primary shading language, but human-readable GLSL shaders cannot be used with Vulkan directly, requiring compilation to low-level intermediate representation known as SPIR-V (Standard Portable Intermediate Representation for Vulkan). Many engines do this offline, but Dagon pre-compiles shaders at runtime, leveraging GLSLang library, and caches SPIR-V modules to disk for reuse. This means the very first run of the game takes some time, but at subsequent runs shaders are loaded very fast.

Most of the shaders utilized by Dagon's renderer are managed fully automatically. If you write your own shaders, you still can use the shader cache, or you can load them fully by yourself bypassing built-in mechanisms, and provide GLSL strings for vertex and fragment programs. You can even use a third-party shader toolchain and provide compiled SPIR-V modules instead of GLSL source code. In all cases, it is important to follow Dagon's pipeline conventions.

TODO: conventions
