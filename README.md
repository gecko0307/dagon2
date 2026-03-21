# Dagon 2

Work-in-progress SDL3 port of [Dagon engine](https://github.com/gecko0307/dagon).

[![comparison](https://blog.pixperfect.online/wp-content/uploads/2026/03/dagon2_vs_eevee_ssao.jpg)](https://blog.pixperfect.online/wp-content/uploads/2026/03/dagon2_vs_eevee_ssao.jpg)

New features:
- Rendering is based on SDL GPU, targeting Vulkan instead of OpenGL
- Many improvements in deferred renderer. The image is now almost identical to Blender's Eevee
- Multiple scattering support
- Experimental HDR (scRGB) output support
- Supersampling support
- BC7 texture compressor based on D port of Rich Geldreich's [bc7enc](https://github.com/richgel999/bc7enc_rdo)
- Built-in texture caching. Abstract resource cache (`dagon.resource.cache`) that can be used for any file types
- Many new DDS/DXGI formats support
- Shadeless materials in deferred pipeline
- Window minimize/restore events.

Major changes from Dagon 0.x/1.x:
- Reimplemented `dagon.render` (WIP). Deferred renderer, post-processing renderer and presentation renderer are now combined into one
- Shader workflow is now based on GLSL 4.60 and includes built-in GLSL to SPIR-V compiler. SPIR-V modules are cached to disk and reused
- Texture loader is fully based on SDL3_Image and doesn't use `dlib.image.io`
- Semantic of `Scene` and `World` classes is changed. `Scene` is now just a container for Entities and other graphical data; for user input and game logics `World` should be used
- All Entities are static by default, and their model matrices are not recalculated each frame to reduce CPU overhead. For dynamic updates enable `Entity.dynamic` or use custom `EntityController` (partly analogous to old `EntityComponent`)
- The renderer now uses separate irradiance cubemap.
