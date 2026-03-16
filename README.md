# Dagon 2

Work-in-progress SDL3 port of [Dagon engine](https://github.com/gecko0307/dagon).

New features:
- The renderer is based on SDL GPU, targeting Vulkan instead of OpenGL
- Experimental HDR output support
- Many new DDS/DXGI formats support
- Window minimize/restore events
- Abstract resource cache (`dagon.resource.cache`) that can be used for any file types
- Shadeless materials in deferred pipeline.

Major changes from Dagon 0.x/1.x:
- Reimplemented `dagon.render` (WIP)
- Shader workflow is now based on GLSL 4.60, GLSLang compiler + SPIRV-Cross. SPIR-V modules are cached to disk and reused
- Texture loader is fully based on SDL3_Image and doesn't use `dlib.image.io`
- Semantic of `Scene` and `World` classes is changed. `Scene` is now just a container for Entities and other graphical data; for user input and game logics `World` should be used
- All Entities are static by default, and their model matrices are not recalculted each frame. For dynamically transformed Entities `EntityController` should be used (partly analogous to old `EntityComponent`)
