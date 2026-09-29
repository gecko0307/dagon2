# 3D Models

Models (and even entire scenes) in Dagon are loaded from external files. Unfortunately, there is no single industry-standard choise of a 3D model format. Many formats were designed over the years, targeting different rendering systems and providing vastly different feature sets. Dagon 2 supports many model formats thanks to the [Assimp](https://github.com/assimp/assimp) library, but not all of them are optimal for use as game assets. Some formats remain popular simply because they are widely supported by 3D modeling software:

- **Wavefront OBJ** - a simple textual format for static meshes. Not efficient at all, but still very popular and highly portable across different software
- **glTF** - open standard developed by Khronos, designed for real-time 3D applications and the Web. It supports many modern features, including PBR materials, skeletal animation, and scene hierarchies. Software support is generally good
- **FBX** - proprietary interchange format owned by Autodesk. Widely supported by major commercial 3D packages.

These formats are perfectly usable in Dagon applications, but the recommended format for native Dagon assets is DAF (Dagon Asset Format). It is specifically designed for fast loading and efficient runtime access, following the zero-copy principle whenever possible. DAF is also tailored to the features and data layout used by Dagon 2, avoiding the need to convert general-purpose interchange data at load time.

DAF files can be exported from Blender 5 using the corresponding addon located in the `tools/blender/io_export_daf` directory.

TODO: DAF export details.
