# Rendering

Dagon provides a comprehensive hybrid renderer (deferred+forward) built on Vulkan with physically-based material workflow (PBR). It is designed to be data-compatible with Blender's Eevee and gives results very close to it.

## Deferred Rendering
Deferred rendering is one of the two major techniques in rasterization. It breaks rendering into two main phases—geometry pass and light pass. First all visible geometry is rasterized into a set of fragment attribute buffers (often collectively called a G-buffer), which include depth buffer, normal buffer, color buffer, etc. Then a desired number of light bounding volumes are rasterized into a final radiance buffer. A light shader calculates radiance for a given fragment based on light's properties and G-buffer values corresponding to that fragment.

Deferred rendering has the following advantages over forward rendering:
* No hardcoded limit on light number. In practice, the number of lights is limited only by GPU fillrate, not some fixed maximum.
* No hardcoded limit on light model variety. Forward rendering can handle only strictly limited set of predefined light models—usually point, spot and directional. With deferred, you can implement custom lights in addition to these. Adding a new light model is a matter of writing a new light volume shader.
* No redundant GPU work. Classic forward renderer (without depth prepass) does full radiance calculation for every fragment, no matter if it will be discarded by depth test afterwards. Deferred renderer, by its nature, calculates radiance only for final visible fragments. For complex scenes this can matter at lot.
* Smaller and thus faster shaders. With forward renderer you usually end up writing big, branched "ubershaders" that handle every possible lighting scenario. In deferred, all functionality is decomposed to separate smaller passes. However, deferred pipeline requires more framebuffer switches.
* G-buffer can be used not only for computing radiance, but also for post-processing, most notably screen-space effects (SSAO, SSLR). In forward renderer this is not possible without depth and normal prepass.

There are some disadvantages as well:
* Higher VRAM and memory bandwidth requirements. This actually matters only for mobile platforms and less of an issue on desktop.
* No simple way of handling transparency. We can't simply blend a fragment to G-buffer over existing data because then the resulting attributes will be meaningless. Transparent objects are usually discarded at the geometry pass and rendered in forward mode as a final step after the light pass. This means that they can't be lit with deferred light volumes and should be handled with some fallback lighting technique.
* Less material variety. In a classic deferred renderer BRDF is defined by light volume shaders, so we can have different BRDFs per light, but not per material. This limitation is less critical if a renderer uses PBR principles (albedo, roughness and metallic maps, microfacet BRDF, image-based lighting, etc.). PBR, which is de-facto standard way of defining materials nowadays, allows greater variety of common materials, such as colored metals, shiny and rough dielectrics, and any combinations of them on the same surface. PBR extension of a deferred renderer comes at additional VRAM cost, but the outcome is very good. Again, objects with custom BRDFs (which you actually don't have too much in typical situations) can be rendered in forward mode.
* Deferred shading is incompatible with MSAA. Common workaround is to use post-process antialiasing (FXAA, TAA, SMAA).
