module dagon.graphics.texturebuffer;

import dagon.core.sdl3;
import dagon.core.dxgiformat;
import dagon.core.logger;

/**
 * Specifies the dimension of a texture.
 */
enum TextureDimension
{
    /// Unknown
    Undefined,

    /// 1-dimensional texture
    D1,

    /// 2-dimensional texture
    D2,

    /// 3-dimensional texture
    D3
}

/**
 * Represents the size of a texture in pixels.
 */
struct TextureSize
{
    /// Width
    uint width;

    /// Height
    uint height;

    /// Depth
    uint depth;
}

/**
 * The faces of a cube map texture.
 */
enum CubeFace: uint
{
    /// Positive-X face (right)
    PositiveX = SDL_GPU_CUBEMAPFACE_POSITIVEX,

    /// Negative-X face (left)
    NegativeX = SDL_GPU_CUBEMAPFACE_NEGATIVEX,

    /// Positive-Y face (top)
    PositiveY = SDL_GPU_CUBEMAPFACE_POSITIVEY,

    /// Negative-Y face (bottom)
    NegativeY = SDL_GPU_CUBEMAPFACE_NEGATIVEY,

    /// Positive-Z face (front)
    PositiveZ = SDL_GPU_CUBEMAPFACE_POSITIVEZ,

    /// Negative-Z face (back)
    NegativeZ = SDL_GPU_CUBEMAPFACE_NEGATIVEZ
}

/**
 * Bitmask for cube map faces.
 */
enum CubeFaceBit
{
    None = 0,
    PositiveX = 1,
    NegativeX = 2,
    PositiveY = 4,
    NegativeY = 8,
    PositiveZ = 16,
    NegativeZ = 32,
    All = 0xffffffff
}

/**
 * Returns a corresponding `CubeFaceBit` for a given `CubeFace`
 */
CubeFaceBit cubeFaceBit(CubeFace face)
{
    CubeFaceBit cfb = CubeFaceBit.None;
    switch(face)
    {
        case CubeFace.PositiveX: cfb = CubeFaceBit.PositiveX; break;
        case CubeFace.NegativeX: cfb = CubeFaceBit.NegativeX; break;
        case CubeFace.PositiveY: cfb = CubeFaceBit.PositiveY; break;
        case CubeFace.NegativeY: cfb = CubeFaceBit.NegativeY; break;
        case CubeFace.PositiveZ: cfb = CubeFaceBit.PositiveZ; break;
        case CubeFace.NegativeZ: cfb = CubeFaceBit.NegativeZ; break;
        default: break;
    }
    return cfb;
}

/**
 * Describes the format and layout of a texture.
 */
struct TextureFormat
{
    /// SDL GPU texture type.
    SDL_GPUTextureType type;
    
    /// SDL GPU texture format.
    SDL_GPUTextureFormat format;
    
    /**
     * For compressed formats, this should be the size of a 4x4 pixel block in bytes.
     * For uncompressed formats, this should be zero.
     */
    uint blockSize;

    /// Bitwise combination of `CubeFaceBit` members.
    uint cubeFaces;
    
    /// The number of channels.
    uint numChannels;
    
    /// The size of a pixel in bytes.
    uint pixelSize;
    
    /// Returns `true` if the format is a cube map.
    bool isCubemap() const @property
    {
        return cubeFaces != CubeFaceBit.None;
    }
    
    /// 
    bool isCompressed() const @property
    {
        return blockSize > 0;
    }
    
    /// Returns the texture dimension.
    TextureDimension dimension() const @property
    {
        if (type == SDL_GPU_TEXTURETYPE_2D)
            return TextureDimension.D2;
        else if (type == SDL_GPU_TEXTURETYPE_3D)
            return TextureDimension.D3;
        else
            return TextureDimension.Undefined;
    }
}

/**
 * Intermediate texture data storage.
 * Used to create textures loaded from container formats,
 * such as DDS and KTX, from custom formats, or directly
 * from memory.
 */
struct TextureBuffer
{
    /// Format of a texture data.
    TextureFormat format;

    /// Size of a texture data.
    TextureSize size;

    /// Number of mip levels.
    uint mipLevels;

    /// Raw texture data (can be compressed).
    ubyte[] data;
}

/**
 * Converts DirectX texture format to SDL GPU texture format.
 *
 * Params:
 *   fmt = DXGIFormat.
 *   tf = Output SDL_GPUTextureFormat.
 * Returns:
 *   true if format is supported, false otherwise.
 */
bool dxgiFormatToSDLFormat(DXGIFormat fmt, out TextureFormat tf)
{
    switch(fmt)
    {
        case DXGIFormat.R32G32B32A32_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32B32A32_UINT;
            tf.numChannels = 4;
            tf.pixelSize = 16;
            break;
        case DXGIFormat.R32G32B32A32_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32B32A32_FLOAT;
            tf.numChannels = 4;
            tf.pixelSize = 16;
            break;
        case DXGIFormat.R32G32B32A32_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32B32A32_UINT;
            tf.numChannels = 4;
            tf.pixelSize = 16;
            break;
        case DXGIFormat.R32G32B32A32_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32B32A32_INT;
            tf.numChannels = 4;
            tf.pixelSize = 16;
            break;
        case DXGIFormat.R16G16B16A16_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UINT;
            tf.numChannels = 4;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R16G16B16A16_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
            tf.numChannels = 4;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R16G16B16A16_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R16G16B16A16_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UINT;
            tf.numChannels = 4;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R16G16B16A16_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_SNORM;
            tf.numChannels = 4;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R16G16B16A16_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_INT;
            tf.numChannels = 4;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R32G32_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R32G32_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32_FLOAT;
            tf.numChannels = 2;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R32G32_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R32G32_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32G32_INT;
            tf.numChannels = 2;
            tf.pixelSize = 8;
            break;
        case DXGIFormat.R10G10B10A2_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R10G10B10A2_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R10G10B10A2_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R10G10B10A2_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R10G10B10A2_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R10G10B10A2_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R11G11B10_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R11G11B10_UFLOAT;
            tf.numChannels = 3;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R8G8B8A8_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UINT;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R8G8B8A8_UNORM, DXGIFormat.R8G8B8A8_UNORM_SRGB:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R8G8B8A8_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UINT;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R8G8B8A8_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_SNORM;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R8G8B8A8_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_INT;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R16G16_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R16G16_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16_FLOAT;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R16G16_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16_UNORM;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R16G16_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R16G16_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16_SNORM;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R16G16_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16G16_INT;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R32_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32_UINT;
            tf.numChannels = 1;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R32_FLOAT, DXGIFormat.D32_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32_FLOAT;
            tf.numChannels = 1;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R32_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32_UINT;
            tf.numChannels = 1;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R32_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R32_INT;
            tf.numChannels = 1;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.D24_UNORM_S8_UINT, DXGIFormat.R24_UNORM_X8_TYPELESS, DXGIFormat.X24_TYPELESS_G8_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_D24_UNORM_S8_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.R8G8_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R8G8_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8_UNORM;
            tf.numChannels = 2;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R8G8_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8_UINT;
            tf.numChannels = 2;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R8G8_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8_SNORM;
            tf.numChannels = 2;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R8G8_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8G8_INT;
            tf.numChannels = 2;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R16_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16_UINT;
            tf.numChannels = 1;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R16_FLOAT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16_FLOAT;
            tf.numChannels = 1;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R16_UNORM, DXGIFormat.D16_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16_UNORM;
            tf.numChannels = 1;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R16_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16_UINT;
            tf.numChannels = 1;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R16_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16_SNORM;
            tf.numChannels = 1;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R16_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R16_INT;
            tf.numChannels = 1;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.R8_TYPELESS:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8_UINT;
            tf.numChannels = 1;
            tf.pixelSize = 1;
            break;
        case DXGIFormat.R8_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8_UNORM;
            tf.numChannels = 1;
            tf.pixelSize = 1;
            break;
        case DXGIFormat.R8_UINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8_UINT;
            tf.numChannels = 1;
            tf.pixelSize = 1;
            break;
        case DXGIFormat.R8_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8_SNORM;
            tf.numChannels = 1;
            tf.pixelSize = 1;
            break;
        case DXGIFormat.R8_SINT:
            tf.format = SDL_GPU_TEXTUREFORMAT_R8_INT;
            tf.numChannels = 1;
            tf.pixelSize = 1;
            break;
        case DXGIFormat.A8_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_A8_UNORM;
            tf.numChannels = 1;
            tf.pixelSize = 1;
            break;
        case DXGIFormat.BC1_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM;
            tf.blockSize = 8;
            break;
        case DXGIFormat.BC2_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC2_RGBA_UNORM;
            tf.blockSize = 16;
            break;
        case DXGIFormat.BC3_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM;
            tf.blockSize = 16;
            break;
        case DXGIFormat.BC4_UNORM, DXGIFormat.BC4_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC4_R_UNORM;
            tf.blockSize = 16;
            break;
        case DXGIFormat.BC5_UNORM, DXGIFormat.BC5_SNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC5_RG_UNORM;
            tf.blockSize = 16;
            break;
        case DXGIFormat.B5G6R5_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_B5G6R5_UNORM;
            tf.numChannels = 3;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.B5G5R5A1_UNORM:
            tf.format = SDL_GPU_TEXTUREFORMAT_B5G5R5A1_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 2;
            break;
        case DXGIFormat.B8G8R8A8_UNORM, DXGIFormat.B8G8R8X8_UNORM, DXGIFormat.B8G8R8A8_TYPELESS,
             DXGIFormat.B8G8R8A8_UNORM_SRGB, DXGIFormat.B8G8R8X8_TYPELESS, DXGIFormat.B8G8R8X8_UNORM_SRGB:
            tf.format = SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM;
            tf.numChannels = 4;
            tf.pixelSize = 4;
            break;
        case DXGIFormat.BC6H_SF16:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC6H_RGB_FLOAT;
            tf.blockSize = 16;
            break;
        case DXGIFormat.BC6H_UF16:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC6H_RGB_UFLOAT;
            tf.blockSize = 16;
            break;
        case DXGIFormat.BC7_UNORM, DXGIFormat.BC7_UNORM_SRGB:
            tf.format = SDL_GPU_TEXTUREFORMAT_BC7_RGBA_UNORM;
            tf.blockSize = 16;
            break;
        case DXGIFormat.ASTC_4X4_UNORM, DXGIFormat.ASTC_4X4_UNORM_SRGB:
            tf.format = SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM;
            tf.blockSize = 16;
            break;
        // TODO: other ASTC formats
        default:
            logWarning("Unsupported DXGIFormat");
            return false;
    }
    
    return true;
}
