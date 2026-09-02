# Materials

Material in Dagon is a description of entity's surface properties. Dagon implements physically based rendering (PBR) and follows roughness/metallic workflow for materials.

## PBR

PBR a combination of rendering techniques that bring real-time graphics closer to real world by following laws of optics. PBR operates on a unified set of inputs that are completely independent from lighting, so PBR materials look consistent in any environment and are usually portable between different graphics software and game engines.

## Material Properties

`baseColor` and `baseColorTexture` - color of a surface. This is also called albedo or diffuse color. The alpha channel defines surface transparency if `blendMode` property is set to `Transparent`. Color data must be in sRGB space. If `baseColorTexture` is assigned, `baseColor` is interpreted as a multiplier for the values sampled from the texture. Otherwise, `baseColor` is used directly. This allows to colorize surfaces without adding new textures. Effectively, to use `baseColorTexture` as is, `baseColor` must be `[1.0, 1.0, 1.0, alpha]`.

`roughness` - roughness of a surface, a number between `0.0` and `1.0`. Dagon's shading model (GGX) treats all surfaces as consisting of microscopic perfect mirrors (microfacets). The roughness parameter can be understood as a probability of microfacet normal's random deviation from the geometric normal of a surface. Visually, this affects blurriness of a specular reflection. Materials like metal, shiny plastic or polished wood have low roughness, and materials like raw stone, concrete or cloth have high roughness. Default value is `0.5`.

`metallic` - metalness of a surface, a number between `0.0` and `1.0`. It defines the surface's material type: non-metal (dielectric) or metal (conductor). A value of 0.0 means the surface behaves like a non-metal (e.g., plastic, wood, fabric), and 1.0 means it behaves like a pure metal (e.g., iron, gold, copper). Intermediate values can be used for simulating oxidized metal surfaces. Default value is `0.0`. In Dagon's shading model, this parameter determines how light interacts with microfacets:
* For non-metals (metallic = 0), microfacets reflect only specular light and have a separate diffuse response based on `baseColor`.
* For metals (metallic = 1), the surface has no diffuse reflection - all reflected light is specular, colored by `baseColor`.
Microfacets are considered perfect mirrors at microscopic scale, but only for metals their reflectance dominates, while for dielectrics, much of the incoming light is scattered diffusely beneath the surface. Effectively, `metallic` defines the chemical composition of the surface, while `roughness` defines its microscopic geometric structure.

`roughnessMetallicTexture` - combined roughness/metallic texture. Green channel stores roughness, blue channel stores metalness (as defined by glTF 2.0 specification). Data must be in linear space.

`emissionColor` and `emissionTexture` - self-illumination color. Must be in sRGB. If `emissionTexture` is assigned, `emissionColor` is interpreted as a multiplier for the values sampled from the texture. Otherwise, `emissionColor` is used directly. This allows to colorize surfaces without adding new textures. Effectively, to use `emissionTexture` as is, `emissionColor` must be `[1.0, 1.0, 1.0, 1.0]`. `emissionEnergy` should be larger than zero for emission to take effect. Alpha value for emission data is not used.

`emissionEnergy` - self-illumination brightness. Default value is `0.0`.

`normalTexture` - normal map of a surface in tangent space. Each pixel encodes a normal with the following formula: `N * 0.5 + 0.5`. Dagon uses OpenGL convention for normal maps: the X-axis (red channel) points to the right, the Y-axis (green channel) points up, and the Z-axis (blue channel) is perpendicular to the image plane.

`heightTexture` - height map of a surface, a monochrome image where dark areas mean lower height, and light areas mean higher height. When using parallax mapping, it is used to displace texture coordinates and give a surface more bumpy look.

`ior` - index of refraction. Used to derive base reflectivity (f₀), the percentage of light reflected when looking straight at a surface. For most materials, IOR is between `1.0` (air) and `4.0` (germanium). Default value is `1.5`, which yields standard dielectric f₀ = 0.04 (given `iorLevel` is `0.5`).

`iorLevel` - intensity of specular reflection. Default value is `0.5`.

`subsurfaceScattering` - portion of light that scatters beneath the surface, a number between `0.0` and `1.0`. This is useful for translucent materials such as skin or wax. Default value is `0.0`.

`opacity` - surface opacity factor, a number between `0.0` and `1.0`. Base color alpha is multiplied by this value to enable animated fade effects.

`alphaClipThreshold` - surface with `alpha * opacity` lower than this threshold will be invisible (discarded as fully transparent) in the deferred pipeline.

`shadeless` -  if true, the surface is not affected by any lights. The resulting look is determined by baseColor/baseColorTexture. This is useful for interface objects in the scene (like guidelines or arrows).

`skyboxTexture` - an optional cubemap texture for skybox rendering. If assigned, `emissionTexture` is ignored, instead the skybox texture data is written to the emission buffer. Typically used for `EntityLayer.Background` entities, and with `shadeless` and `outputDepth` turned off.

`skyboxTextureMipLevel` - mip level to use for sampling `skyboxTexture`.

`outputDepth` - determines if the renderer should write eye space Z coordinate of the surface to the depth buffer. If disabled, the constant value is written (currently 1.0). If the object should be rendered at the background, this should be disabled.

`blendMode` - blend mode of the surface. Currently two blend modes are supported: `BlendMode.Opaque` and `BlendMode.Transparent`.

`uvTransformation` - 4x4 matrix used to dynamically transform mesh UV coordinates. This allows to scale, offset and rotate the texture mapping on a surface. The pipeline actually uses only an upper-left 3x3 portion of this matrix (4x4 is only used for transfer, complying with std140 layout rules). To assign a 3x3 matrix, use `Material.uvTransformation3x3` property setter.
