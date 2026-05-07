# Rendering

Dagon provides a comprehensive hybrid renderer (deferred+forward) built on Vulkan with physically-based material workflow (PBR). It is designed to be data-compatible with Blender's Eevee and gives results very close to it.

## Deferred Rendering
Deferred rendering is one of the two major techniques in rasterization. It breaks rendering into two main phases—geometry pass and light pass. First all visible geometry is rasterized into a set of fragment attribute buffers (often collectively called a G-buffer), which include depth buffer, normal buffer, color buffer, etc. Then a desired number of light bounding volumes are rasterized into a final radiance buffer. A light shader calculates radiance for a given fragment based on light's properties and G-buffer values corresponding to that fragment.

Deferred rendering has the following advantages over forward rendering:
* No hardcoded limit on light number. In practice, the number of lights is limited only by GPU fillrate, not some fixed maximum
* No hardcoded limit on light model variety. Forward rendering can handle only strictly limited set of predefined light models—usually point, spot and directional. With deferred, you can implement custom lights in addition to these. Adding a new light model is a matter of writing a new light volume shader
* No redundant GPU work. Classic forward renderer (without depth prepass) does full radiance calculation for every fragment, no matter if it will be discarded by depth test afterwards. Deferred renderer, by its nature, calculates radiance only for final visible fragments. For complex scenes this can matter a lot
* Smaller and thus faster shaders. With forward renderer you usually end up writing big, branched "ubershaders" that handle every possible lighting scenario. In deferred, all functionality is decomposed to separate smaller passes. However, deferred pipeline requires more framebuffer switches
* G-buffer can be used not only for lighting, but also for post-processing, most notably screen-space effects (SSAO, SSLR). In forward renderer this is not possible without depth and normal prepass.

There are some disadvantages as well:
* Higher VRAM and memory bandwidth requirements. This actually matters only for mobile platforms and less of an issue on desktop
* No simple way of handling transparency. You can't simply blend a fragment to G-buffer over existing data because then the resulting attributes will be meaningless. Transparent objects are usually discarded at the geometry pass and rendered in forward mode as a final step after the light pass. This means that they can't be lit with deferred light volumes and should be handled with some fallback lighting technique
* Less material variety. In a classic deferred renderer BRDF is defined by light volume shaders, so you can have different BRDFs per light, but not per material. This limitation is less critical if a renderer uses PBR principles (albedo, roughness and metallic maps, microfacet BRDF, image-based lighting, etc.). PBR, which is de-facto standard way of defining materials nowadays, allows greater variety of common materials, such as colored metals, shiny and rough dielectrics, and any combinations of them on the same surface. PBR extension of a deferred renderer comes at additional VRAM cost, but the outcome is very good. Again, objects with custom BRDFs (which you actually don't have too much in typical situations) can be rendered in forward mode
* Deferred shading is incompatible with MSAA. Common workaround is to use post-process antialiasing (FXAA, TAA, SMAA).

### PBR

Dagon implements idiomatic PBR (metallic/roughness workflow) heavily based on the theory described in [Real Shading in Unreal Engine 4](https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf). It utilizes physically-based GGX/Trowbridge-Reitz model, analogous to Disney Principled BRDF.

GGX is based on the Cook-Torrance microfacet specular model and combines normal distribution term (D), Smith geometric shadowing-masking term (G), and Fresnel term (F).

Specular radiance equation:

```
Ls = (D * G * F) / (4 * NV * NL)
```

Diffuse radiance equation:

```
Ld = 1/PI * albedo * (1 - F) * NL * occlusion * (1 - metallic)
```

### Image-Based Lighting

IBL is a standard rendering technique to achieve approximated global illumination in a very computationally inexpensive way, which works best in outdoor scenes. The "infinitely far" environment of a scene (such as the sky and the surrounding landscape) is pre-baked into an environment map. Environment maps are typically captured using 360° photography, or rendered from 3D scenes. IBL is a very efficient way to add realism to computer games, especially in the PBR pipeline.

Dagon implements an industry-standard IBL method known as the split sum approximation. Introduced by Brian Karis in Epic Games, it splits the rendering equation into two precomputable parts: a pre-filtered environment map and a 2D lookup table, sometimes called a BRDF integration map or DFG (Distribution, Fresnel, Geometry). This red-green LUT outputs a scale (red channel) and an offset (green channel) for the Fresnel term for different roughness values and viewing angles.

Pre-filtered environment map is generated by convolving the input cube map using GGX BRDF for different roughness levels. They are stored in the mip chain of the cube map and then sampled in the shader to get a specular reflection for the given material roughness. Such a map can be pre-baked using an external tool and saved to DDS or KTX for direct uploading to VRAM, or generated in the engine from an equirectangular map. Dagon implements this via importance sampling of an equirectangular map by the van der Corput-Hammersley distribution on a hemisphere. The computation is GPU-accelerated, and usually is very fast.

Equirectangular mapping uses a single 2D image and spherical coordinate space to encode the environment. Equirectangular projection maps spherical coordinates to planar coordinates: meridians to vertical straight lines of constant spacing, and circles of latitude to horizontal straight lines of constant spacing. Consequently, it preserves high precision along the equator and introduces severe distortion at the poles. Most of the HDR environment maps available on the Internet use this format because of its simplicity and efficiency.

### Subsurface Scattering

Dagon's deferred pipeline supports subsurface scattering based on Hanrahan-Krueger approximation of isotropic BSSRDF, like in the Disney Principled BRDF.

### Screen-Space Reflections

Screen-space reflections are a technique to achieve approximated dynamic reflections in real time. It works per-pixel by raymarching through the depth buffer along the reflection vector and sampling the HDR buffer at the point where the ray hits reconstructed geometry. Given sufficient precision, the basic technique gives mirror-like reflections. To support glossy reflections, stochastic methods are used: the ray is thrown at randomized direction, effectively sampling the specular lobe of the given BRDF. This by itself gives very noisy reflections due to undersampling, but the results can be accumulated over time and smoothed out using exponential moving average, which finally make SSR look convincing and viable for real use.

Like all screen-space effects, SSR suffers from inherent information discontinuities. It's only possible to reconstruct geometry which is directly visible on screen, and this results in holes and gaps in reflections when the ray hits nothing in the depth buffer. This is also why screen-space reflections disappear when objects go off-screen (for example, when the camera looks down). Thus SSR is only practical when combined with a fallback global reflection method, which is usually environment probes.

### HDR

Dagon's renderer outputs radiance into a floating-point frame buffer without clamping the values to 0..1 range, so the buffer contains greater luminance information compared to traditional integer frame buffer. The final image that is visible on screen is a result of an additional tone mapping pass, which applies a non-linear luminance compression to the incoming values. Very dark and very bright pixels are compressed more, and pixels of a medium brightness are compressed less.

Dagon utilizes AgX tone mapper from Blender 4.0+ and Filament, which provides great color accuracy and balance.

Dagon also supports direct output to wide-gamut HDR buffer without tone mapping pass. This requires HDR-capable display and operating system support.
