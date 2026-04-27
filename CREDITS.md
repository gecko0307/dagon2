# Credits

## Authors and contributors
* Core engine, GScript3 runtime, Jolt Physics binding - [Timur Gafarov aka gecko0307](https://github.com/gecko0307)
* OBJ group parser - [Vlad Davydov aka Tynuk](https://github.com/Tynukua)

## Adapted third-party code
* DXT1/DXT5 compressor - [Fabian Giesen](https://github.com/rygorous), [Yann Collet](https://github.com/Cyan4973)
* BC7 compressor - [Rich Geldreich](https://github.com/richgel999)
* SSAO implementation is based on the code by [Reinder Nijhoff](https://www.shadertoy.com/view/Ms33WB)
* FXAA implementation is based on the code by [JeGX](http://www.geeks3d.com/20110405/fxaa-fast-approximate-anti-aliasing-demo-glsl-opengl-test-radeon-geforce)
* Sharpening shader is based on AMD's [FidelityFX™ CAS](https://gpuopen.com/fidelityfx-cas/)
* Cubemap prefiltering shader is based on the code by [Joey de Vries](https://learnopengl.com/)
* Hammersley point set calculation is based on the radical inverse function by [Holger Dammertz](http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html)
* AgX tonemapper is based on the code by [Don McCurdy](https://github.com/mrdoob), which in turn is based on Blender and Filament implementations

## Third-party libraries
Dagon 2 depends on the following libraries:
* [Simple DirectMedia Layer (SDL)](https://www.libsdl.org/)
* [SDL_Image](https://github.com/libsdl-org/SDL_image)
* [FreeType](https://freetype.org/)
* [libtiff](https://gitlab.com/libtiff/libtiff)
* [libwebp](https://chromium.googlesource.com/webm/libwebp)
* [libktx](https://github.com/KhronosGroup/KTX-Software)
* [Jolt Physics](https://github.com/jrouwe/JoltPhysics) via [joltc](https://github.com/amerkoleci/joltc) wrapper
