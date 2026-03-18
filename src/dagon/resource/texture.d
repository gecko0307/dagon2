module dagon.resource.texture;

import std.math;
import std.string;
import std.path;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.core.stream;
import dlib.math.utils;
import dlib.filesystem.filesystem;

import dagon.core.sdl3;
import dagon.core.application;
import dagon.core.gpu;
import dagon.core.dxt;
import dagon.core.logger;
import dagon.graphics.texturebuffer;
import dagon.graphics.texture;
import dagon.resource.image;
import dagon.resource.dds;
import dagon.resource.hdr;

///
enum TextureCompressionFormat
{
    DXT1 = 0,
    DXT5 = 1
}

///
class TextureAsset: Owner
{
    ///
    GPU gpu;
    
    ///
    TextureBuffer buffer;
    
    ///
    Texture texture;
    
    ///
    ImageConversionOptions conversion;
    
    ///
    bool generateMipmaps = true;
    
    ///
    bool repeatUV = true;
    
    ///
    bool compress = false;
    
    ///
    bool cache = false;
    
    ///
    bool persistent = false;
    
    ///
    bool loaded = false;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
        conversion.width = 0;
        conversion.height = 0;
        conversion.hint = 0;
    }
    
    ~this()
    {
        releaseBuffer();
    }
    
    protected void releaseBuffer()
    {
        if (buffer.data.length)
        {
            Delete(buffer.data);
            buffer.data = [];
        }
    }
    
    bool load(string filename, InputStream istrm, ReadOnlyFileSystem fs)
    {
        string name = filename.baseName;
        
        ubyte[] data = globalResourceCache.load(ResourceType.Texture, name, filename, &textureLoadCallback, &buffer);
        if (data.length)
        {
            Delete(data);
        }
        else
        {
            logDebug("Decoding ", name, "...");
            
            string extension = filename.extension.toLower;
            
            if (extension == ".dds")
            {
                loaded = loadDDS(istrm, &buffer);
            }
            else if (extension == ".hdr")
            {
                loaded = loadHDR(istrm, &buffer);
            }
            else if (isSupportedImageFormat(extension))
            {
                loaded = loadImage(istrm, extension, &buffer, &conversion);
            }
            // TODO: custom loaders
            
            if (!loaded)
            {
                if (!persistent)
                    releaseBuffer();
                return false;
            }
            
            if (compress && !buffer.format.isCompressed)
            {
                if (buffer.format.type == SDL_GPU_TEXTURETYPE_2D &&
                    buffer.format.format == SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM)
                {
                    // Compress to DXT5
                    logInfo("Compressing ", filename, " to DXT5/BC3");
                    compressTexture(TextureCompressionFormat.DXT5);
                    generateMipmaps = false;
                }
                else
                {
                    logWarning(
                        filename, ": ",
                        "texture compression for type ", textureTypeStr(buffer.format.type),
                        " and format ", textureFormatStr(buffer.format.format),
                        " is not supported");
                }
            }
            
            if (cache)
                globalResourceCache.save(ResourceType.Texture, name, &textureSaveCallback, &buffer);
        }
        
        texture = New!Texture(gpu, this);
        TextureCreationOptions options = {
            generateMipmaps: generateMipmaps,
            repeatUV: repeatUV
        };
        loaded = texture.create(&buffer, &options);
        
        if (!persistent)
            releaseBuffer();
        
        return loaded;
    }
    
    protected void compressTexture(TextureCompressionFormat compressionFormat)
    {
        uint width = buffer.size.width;
        uint height = buffer.size.height;
        uint numChannels = buffer.format.numChannels;
        uint pSize = buffer.format.pixelSize;
        uint mipLevels;
        
        uint blockSize;
        SDL_GPUTextureFormat newFormat;
        if (compressionFormat == TextureCompressionFormat.DXT1)
        {
            blockSize = 8;
            newFormat = SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM;
        }
        else if (compressionFormat == TextureCompressionFormat.DXT5)
        {
            blockSize = 16;
            newFormat = SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM;
        }
        
        ubyte[] compressedTextureBuffer;
        
        if (generateMipmaps && buffer.mipLevels == 1)
        {
            mipLevels = 1 + cast(uint)floor(log2(cast(double)max2(width, height)));
            
            size_t mipChainSize = 0;
            size_t compressedMipChainSize = 0;
            uint w = width;
            uint h = height;
            foreach (level; 0..mipLevels)
            {
                mipChainSize += w * h * numChannels;
                auto blocksH = (w + 3) / 4;
                auto blocksV = (h + 3) / 4;
                size_t levelSize = blocksH * blocksV * blockSize;
                
                compressedMipChainSize += levelSize;
                w = max2(1, w / 2);
                h = max2(1, h / 2);
            }
            
            ubyte[] mipChainBuffer = New!(ubyte[])(mipChainSize);
            ubyte[] compressedMipChainBuffer = New!(ubyte[])(compressedMipChainSize);
            
            uint levelWidth = width;
            uint levelHeight = height;
            uint prevLevelWidth = levelWidth;
            uint prevLevelHeight = levelHeight;
            
            size_t offset = 0;
            size_t offsetCompressed = 0;

            ubyte[] levelSourceBuffer = buffer.data;
            foreach (level; 0..mipLevels)
            {
                size_t levelSize = levelWidth * levelHeight * numChannels;
                ubyte[] levelBufferSlice;
                
                if (level > 0)
                {
                    levelBufferSlice = mipChainBuffer[offset..offset + levelSize];
                    downsampleBox2x2(levelSourceBuffer, prevLevelWidth, prevLevelHeight, numChannels, levelBufferSlice);
                    offset += levelSize;
                }
                else
                {
                    levelBufferSlice = levelSourceBuffer[offset..offset + levelSize];
                    offset += levelSize;
                }
                
                auto blocksH = max2(1, (levelWidth + 3) / 4);
                auto blocksV = max2(1, (levelHeight + 3) / 4);
                auto levelSizeCompressed = blocksH * blocksV * blockSize; //alignUp(blocksH * blocksV * blockSize, 4);
                ubyte[] levelCompDst = compressedMipChainBuffer[offsetCompressed..offsetCompressed + levelSizeCompressed];
                dxtCompress(levelCompDst.ptr, levelBufferSlice.ptr, levelWidth, levelHeight, compressionFormat);
                offsetCompressed += levelSizeCompressed;
                
                prevLevelWidth = levelWidth;
                prevLevelHeight = levelHeight;
                
                levelWidth = max2(1, levelWidth / 2);
                levelHeight = max2(1, levelHeight / 2);
                
                levelSourceBuffer = levelBufferSlice;
            }
            
            Delete(mipChainBuffer);
            
            compressedTextureBuffer = compressedMipChainBuffer;
        }
        else
        {
            mipLevels = 1;
            uint compressedDataSize = ((width + 3) / 4) * ((height + 3) / 4) * blockSize;
            compressedTextureBuffer = New!(ubyte[])(compressedDataSize);
            dxtCompress(compressedTextureBuffer.ptr, buffer.data.ptr, width, height, compressionFormat);
        }
        
        releaseBuffer();
        buffer.data = compressedTextureBuffer;
        buffer.format.format = newFormat;
        buffer.format.blockSize = blockSize;
        buffer.mipLevels = mipLevels;
    }
}

bool textureSaveCallback(string path, OutputStream outputStream, void* data)
{
    return saveDDS(outputStream, cast(TextureBuffer*)data);
}

bool textureLoadCallback(string path, InputStream inputStream, void* data)
{
    return loadDDS(inputStream, cast(TextureBuffer*)data);
}

///
void downsampleBox2x2(ubyte[] src, uint srcW, uint srcH, uint channels, ubyte[] dst)
{
    uint dstW = srcW > 1 ? srcW / 2 : 1;
    uint dstH = srcH > 1 ? srcH / 2 : 1;
    
    foreach (y; 0..dstH)
    {
        int srcY0 = y * 2;
        int srcY1 = (srcY0 + 1 < srcH) ? srcY0 + 1 : srcY0;

        foreach (x; 0..dstW)
        {
            int srcX0 = x * 2;
            int srcX1 = (srcX0 + 1 < srcW) ? srcX0 + 1 : srcX0;

            int dstIndex = (y * dstW + x) * channels;

            int i00 = (srcY0 * srcW + srcX0) * channels;
            int i10 = (srcY0 * srcW + srcX1) * channels;
            int i01 = (srcY1 * srcW + srcX0) * channels;
            int i11 = (srcY1 * srcW + srcX1) * channels;

            foreach (c; 0..channels)
            {
                uint sum =
                    src[i00 + c] +
                    src[i10 + c] +
                    src[i01 + c] +
                    src[i11 + c];

                // Average: (sum + 2) / 4
                dst[dstIndex + c] = cast(ubyte)((sum + 2) >> 2);
            }
        }
    }
}
