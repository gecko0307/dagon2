Dagon Engine 2
--------------
Feature-rich, performant, easy to use, extensible desktop game development framework for [D language](https://dlang.org/), a work-in-progress SDL3/Vulkan port of [Dagon Engine 1.x](https://github.com/gecko0307/dagon). It works on Windows and Linux.

> Note: this project is not connected to Dagon engine by Senscape.

[![DUB Package](https://img.shields.io/dub/v/dagon2.svg)](https://code.dlang.org/packages/dagon2)
[![DUB Downloads](https://img.shields.io/dub/dt/dagon2.svg)](https://code.dlang.org/packages/dagon2)
[![License](http://img.shields.io/badge/license-boost-blue.svg)](http://www.boost.org/LICENSE_1_0.txt)

Screenshots
-----------
[![Car 1](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-mclaren.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-mclaren.jpg)
[![Car 2](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-color-grading1.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-color-grading1.jpg)
[![Car 3](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-color-grading2.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-color-grading2.jpg)
[![Temporal SSLR test](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-sslr-new2.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-sslr-new2.jpg)
[![Temporal SSLR test](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-sslr-new3.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/05/dagon2-sslr-new3.jpg)

Features
--------
Note: Dagon 2 is still in active development. Not all features and extensions of Dagon 1.0 are ported yet.

New features and major changes from Dagon 0.x/1.x:
- Moved to SDL3
- The renderer now leverages SDL GPU, targeting Vulkan
- Reimplemented `dagon.render`. Deferred renderer, post-processing renderer and presentation renderer are now combined into one
- Improvements and optimizations in almost every stage of the renderer. Many new features such as irradiance mapping, multiple scattering, specular occlusion, and adjustable f0
- Shader workflow is now based on GLSL 4.60 and includes built-in GLSL to SPIR-V compiler. SPIR-V modules are cached to disk for reuse
- Texture loader is fully based on SDL3_Image and doesn't use `dlib.image.io`. KTX support is now a core feature
- Built-in texture caching. Abstract resource cache (`dagon.resource.cache`) that can be used for any file types
- Many new DDS/DXGI formats support
- Assimp integration is now a core feature
- Screen-space reflections
- Temporal SSAO
- Fog effect is now applied in a separate pass. Ground fog support
- Tonemapping is entirely based on AgX. Legacy tonemappers were removed
- HDR (scRGB) output support
- Mailbox VSync mode support. CPU-friendly frame scheduler
- Direct GPUImage LUT support was removed, it now requires conversion to 3D LUT
- Radial optical distortion support
- Shadeless materials in deferred pipeline
- `Environment` class is gone, all environment properties are now part of the `Scene` class
- Better handling of transparent objects. Transparent and opaque meshes are now differentiated per-material, not per-entity. This simplifies asset import and allows mixing transparent and opaque face groups in the same mesh
- Semantic of `Scene` and `World` classes is changed. `Scene` is now just a container for Entities and other graphical data; for user input and game logics `World` should be used
- All Entities are static by default, and their model matrices are not recalculated each frame to reduce CPU overhead. For dynamic updates enable `Entity.dynamic` or use custom `EntityController` (partly analogous to old `EntityComponent`)
- The renderer now uses separate irradiance cubemap
- BRDF LUT is now generated at runtime instead of loading from data/__internal
- Jolt Physics is now built-in as `dagon.jolt` package
- Window minimize/restore events
- Built-in [GScript3](https://github.com/gecko0307/gscript3) virtual machine and scripting API
- Referencing support in *.conf files syntax. Any property can be reused like a variable.

System Requirements
-------------------
Realistic minimum system requirements (for Full HD rendering at 60 fps):
- CPU: Intel Core i3-10100 / AMD Ryzen 3 3100
- RAM: application-dependent, usually 8 Gb minimum
- GPU: Vulkan-capable, tested on GeForce RTX 3050
- VRAM: application-dependent, 6 Gb minimum
- OS: 64-bit Windows 10 or higher / Linux.

Usage
-----
TODO

Runtime Dependencies
--------------------
- [SDL](https://www.libsdl.org) 3.4
- [SDL_Image](https://github.com/libsdl-org/SDL_image) 3.2
- [FreeType](https://www.freetype.org) 2.8.1
- [GLSLang](https://github.com/khronosGroup/glslang)
- [SPIRV-Cross](https://github.com/khronosgroup/spirv-cross)
- [Assimp](https://github.com/assimp/assimp)
- [libktx](https://github.com/KhronosGroup/KTX-Software)
- [Jolt Physics](https://github.com/jrouwe/JoltPhysics) via [joltc](https://github.com/amerkoleci/joltc) wrapper
- [libwebp](https://chromium.googlesource.com/webm/libwebp) for WebP support (optional)
- [libtiff](https://libtiff.gitlab.io/libtiff/) for TIFF support (optional)
- [Dear ImGui](https://github.com/ocornut/imgui) via [cimgui](https://github.com/cimgui/cimgui) wrapper (optional)
- [PhysFS](https://github.com/icculus/physfs) (optional)

Dependencies are automatically deployed on 64-bit Windows and Linux. Under Linux, if you want to use local libraries in Windows way (from application's working directory rather than from the system), add the following to your `dub.json`:

```
"lflags-linux": ["-rpath=$$ORIGIN"]
```

On Windows, some dependencies require Visual C++ v14 Redistributable. You can download an official installer [here](https://aka.ms/vc14/vc_redist.x64.exe). It is recommended to bundle vc_redist.x64.exe with your application's installer for end users.

Known Limitations
-----------------
- The engine doesn't support macOS yet
- Although SDL GPU is a multi-backend API, Dagon 2 currently targets only Vulkan backend.

Documentation
-------------
HTML documentation can be generated from source code using ddox (`dub build -b ddox`). Be aware that documentation is currently incomplete.

License
-------
Distributed under the Boost Software License, Version 1.0 (see accompanying file COPYING or at http://www.boost.org/LICENSE_1_0.txt).
