Dagon Engine 2
--------------
Feature-rich, performant, easy to use, extensible desktop game development framework for [D language](https://dlang.org/), an [SDL3](https://github.com/libsdl-org/SDL) port of [Dagon Engine 1.x](https://github.com/gecko0307/dagon). Works on Windows and Linux.

> Note: this project is not connected to Dagon engine by Senscape.

[![DUB Package](https://img.shields.io/dub/v/dagon2.svg)](https://code.dlang.org/packages/dagon2)
[![DUB Downloads](https://img.shields.io/dub/dt/dagon2.svg)](https://code.dlang.org/packages/dagon2)
[![License](http://img.shields.io/badge/license-boost-blue.svg)](http://www.boost.org/LICENSE_1_0.txt)

Screenshots
-----------
[![Screenshot 1](https://blog.pixperfect.online/wp-content/uploads/2026/08/dagon2-cyberpunk-street4.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/08/dagon2-cyberpunk-street4.jpg)
[![Screenshot 2](https://blog.pixperfect.online/wp-content/uploads/2026/08/dagon2-cyberpunk-street1.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/08/dagon2-cyberpunk-street1.jpg)
[![Screenshot 3](https://blog.pixperfect.online/wp-content/uploads/2026/04/dagon2-pbr-test3.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/04/dagon2-pbr-test3.jpg)
[![Screenshot 4](https://blog.pixperfect.online/wp-content/uploads/2026/08/dagon-sponza-new.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/08/dagon-sponza-new.jpg)

Features
--------
Note: Dagon 2 is still in active development. Not all features and extensions of Dagon 1.0 are ported yet.

New features and major changes from Dagon 0.x/1.x:
- Moved to SDL3
- The renderer now leverages SDL GPU, targeting Vulkan
- Reimplemented `dagon.render`. Deferred renderer, post-processing renderer and presentation renderer are now combined into one
- Improvements and optimizations in almost every stage of the renderer. Many new features such as irradiance mapping, multiple scattering, specular occlusion, and adjustable IOR. All stochastic techniques now use permuted congruential generator as a hash function
- Shader workflow is now based on GLSL 4.60 and includes a built-in GLSL to SPIR-V compiler. SPIR-V modules are cached to disk for reuse
- Texture loader is fully based on [SDL3_Image](https://github.com/libsdl-org/SDL_image) and doesn't use `dlib.image.io`. KTX support is now a core feature
- Built-in texture caching. Abstract resource cache (`dagon.resource.cache`) that can be used for any file types
- Many new DDS/DXGI formats support
- [Assimp](https://github.com/assimp/assimp) integration is now a core feature. glTF and other model formats support now rely on Assimp
- Screen-space reflections
- Temporal SSAO
- Fog effect is now applied in a separate pass. Ground fog support
- Tonemapping is entirely based on AgX. Legacy tonemappers were removed
- HDR (scRGB) output support
- Mailbox VSync mode support. CPU-friendly frame scheduler
- HiDPI logic is now handled partly by the engine itself due to API changes in SDL3
- Direct GPUImage LUT support was removed, it now requires conversion to 3D LUT
- Radial optical distortion support
- Shadeless materials in deferred pipeline
- The renderer now uses separate irradiance cubemap
- BRDF LUT is now generated at runtime instead of loading from `data/__internal`
- GPU texture resampling now uses separable Lanczos filter
- `Environment` class is gone, all environment properties are now part of the `Scene` class
- Better handling of transparent objects. Transparent and opaque meshes are now differentiated per-material, not per-entity. This simplifies asset import and allows mixing transparent and opaque face groups in the same mesh
- Semantic of `Scene` and `World` classes is changed. `Scene` is now just a container for Entities and other graphical data; for user input and game logics `World` should be used
- All Entities are static by default, and their model matrices are not recalculated each frame to reduce CPU overhead. For dynamic updates enable `Entity.dynamic` or use custom `EntityController`
- New camera animation system: `CameraController` that interpolates a camera transformation between two independent states defined by `CameraDriver` objects. This allows to implement complex in-game transitions and cutscene animations
- Inertial rotation support in `FirstPersonViewController`
- Jolt Physics is now built-in as `dagon.jolt` package
- Window minimize/restore events
- Built-in [GScript3](https://github.com/gecko0307/gscript3) virtual machine and scripting API
- Referencing support in *.conf files syntax. Any property can be reused like a variable
- [ImGui](https://github.com/ocornut/imgui) integration (dagon2:imgui extension) now provides a built-in UI boilerplate class
- Audio extension now uses its own SoLoud fork with SDL3 support.

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
- [SoLoud](https://github.com/gecko0307/soloud) (optional)
- [libVLC](https://www.videolan.org/vlc/libvlc.html) (optional)

Dependencies are automatically deployed on 64-bit Windows and Linux. Under Linux, if you want to use local libraries in Windows way (from application's working directory rather than from the system), add the following to your `dub.json`:

```
"lflags-linux": ["-rpath=$$ORIGIN"]
```

On Windows, some dependencies require Visual C++ v14 Redistributable. You can download an official installer [here](https://aka.ms/vc14/vc_redist.x64.exe). It is recommended to bundle vc_redist.x64.exe with your application's installer for end users.

Known Limitations
-----------------
- The engine doesn't support macOS yet.
- Although SDL GPU is a multi-backend API, Dagon 2 currently targets only Vulkan backend.
- `dagon:openvr` extension from Dagon 1.x won't be ported because interop between SDL GPU and OpenVR is not possible; SDL deliberately abstracts and hides the underlying native graphics API handles. OpenXR support is planned for the long term, but will not happen until SDL 3.6.0.

Documentation
-------------
API reference in HTML format can be generated from source code using ddox (`dub build -b ddox`). Be aware that documentation is currently incomplete.

License
-------
Distributed under the Boost Software License, Version 1.0 (see accompanying file COPYING or at http://www.boost.org/LICENSE_1_0.txt).
