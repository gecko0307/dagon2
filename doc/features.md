# Features

* Scene graph
* Virtual file system
* Native [OBJ](https://en.wikipedia.org/wiki/Wavefront_.obj_file) format support. [glTF 2.0](https://www.khronos.org/gltf/), [FBX](https://en.wikipedia.org/wiki/FBX) and many other model formats support via [Assimp](https://github.com/assimp/assimp) library
* Own 3D scene format, DAF, optimized for fast decoding
* Textures in PNG, JPEG, WebP, AVIF, DDS, KTX, KTX2, HDR, SVG and many other formats
* Texture compression support: S3TC (DXTn), RGTC, BPTC, [Basis Universal](https://github.com/BinomialLLC/basis_universal). Built-in DXT1, DXT5, RGTC (BC4, BC5) and BPTC compressors. DDS exporter. DDS texture caching to reduce loading times
* GPU-based texture resizing
* Video support using [libVLC](https://www.videolan.org/vlc/libvlc.html)
* Runs in windowed, fullscreen and borderless fullscreen modes
* HiDPI support
* Vulkan-backed hybrid rendering pipeline (deferred for opaque materials, forward for transparent materials)
* Physically based rendering (PBR) with GGX microfacet BRDF. Metallic-roughness workflow
* HDR rendering with AgX tone mapping
* HDRI environment maps. Equirectangular HDRI to cubemap conversion. GPU-based cubemap prefiltering with importance sampling. Loading prebaked cubemaps from DDS or KTX files
* Directional lights with cascaded shadow mapping
* Normal mapping, parallax mapping
* Deferred decals with normal mapping and PBR material properties
* Cinematic post-processing
* Input from keyboard, mouse and up to 4 gamepads. Input manager with abstract bindings and file-based configuration
* Unicode text input
* Graphics tablet input (Windows-only)
* Ownership memory model
* Entity-component model
* Fast arena allocator
* Compute shaders
* Built-in camera logics for easy navigation: freeview and first person views
* Rigid body physics using [Jolt](https://github.com/jrouwe/joltphysics). Built-in character controller
* Internationalization support
* GUI extension based on [Dear ImGui](https://github.com/ocornut/imgui)
* Native file open/save dialogs (for Windows, GTK, and Qt)
* 2D/3D sound. Various audio formats support including WAV, MP3, OGG/Vorbis, FLAC. Stereo, 5.1, 7.1 support
* Microservices and worker threads for running tasks in background
* Asynchronous thread-safe messaging. Use the message broker built into the event system to communicate between threads and the main loop
* UDP networking based on [ENet](http://enet.bespin.org/). UDP server and asynchronous client that works via the message broker. Optional secure transport layer with elliptic curve encryption and X25519 key exchange
* Loading assets from archives via [PhysFS](https://github.com/icculus/physfs).
