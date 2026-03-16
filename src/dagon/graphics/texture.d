module dagon.graphics.texture;

import std.math;
import std.algorithm;
import std.traits;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.utils;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.logger;
import dagon.graphics.texturebuffer;

struct TextureCreationOptions
{
    bool generateMipmaps;
    bool repeatUV;
}

class Texture: Owner
{
    GPU gpu;
    TextureBuffer buffer;
    SDL_GPUTexture* texture;
    SDL_GPUSampler* sampler;
    uint mipLevels;
    bool valid = false;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
    }
    
    ~this()
    {
        if (texture)
            SDL_ReleaseGPUTexture(gpu.device, texture);
        if (sampler)
            SDL_ReleaseGPUSampler(gpu.device, sampler);
    }
    
    bool create(TextureBuffer* buffer, TextureCreationOptions* options)
    {
        this.buffer = *buffer;
        
        if (options.generateMipmaps)
            mipLevels = 1 + cast(uint)floor(log2(cast(double)max(buffer.size.width, buffer.size.height)));
        else
            mipLevels = 1;
        
        SDL_GPUTextureCreateInfo texCreateInfo;
        texCreateInfo.type = buffer.format.type;
        texCreateInfo.format = buffer.format.format;
        texCreateInfo.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
        texCreateInfo.width = buffer.size.width;
        texCreateInfo.height = buffer.size.height;
        if (buffer.format.isCubemap)
            texCreateInfo.layer_count_or_depth = 6;
        else
            texCreateInfo.layer_count_or_depth = buffer.size.depth;
        texCreateInfo.num_levels = mipLevels;
        texture = SDL_CreateGPUTexture(gpu.device, &texCreateInfo);
        
        if (texture is null)
            return false;
        
        SDL_GPUTransferBufferCreateInfo transferCreateInfo = {
            usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: cast(uint)buffer.data.length
        };
        SDL_GPUTransferBuffer* texTransferBuffer = SDL_CreateGPUTransferBuffer(gpu.device, &transferCreateInfo);
        
        ubyte* map = cast(ubyte*)SDL_MapGPUTransferBuffer(gpu.device, texTransferBuffer, false);
        SDL_memcpy(map, buffer.data.ptr, cast(uint)buffer.data.length);
        
        SDL_UnmapGPUTransferBuffer(gpu.device, texTransferBuffer);
        SDL_GPUCommandBuffer* texCopyCommandBuffer = SDL_AcquireGPUCommandBuffer(gpu.device);
        
        // TODO: compressed formats support
        if (buffer.format.isCubemap)
        {
            SDL_GPUCopyPass* texCopyPass = SDL_BeginGPUCopyPass(texCopyCommandBuffer);
            
            uint offset = 0;
            foreach(faceIndex, face; EnumMembers!CubeFace)
            {
                uint levelWidth = buffer.size.width;
                uint levelHeight = buffer.size.height;
                
                for (uint mipLevel = 0; mipLevel < buffer.mipLevels; mipLevel++)
                {
                    uint levelSize = levelWidth * levelHeight * buffer.format.pixelSize;
                    
                    SDL_GPUTextureTransferInfo source = {
                        transfer_buffer: texTransferBuffer,
                        offset: offset,
                    };
                    SDL_GPUTextureRegion destination = {
                        texture: texture,
                        mip_level: mipLevel,
                        layer: faceIndex,
                        x: 0,
                        y: 0,
                        z: 0,
                        w: levelWidth,
                        h: levelHeight,
                        d: 1
                    };
                    SDL_UploadToGPUTexture(texCopyPass, &source, &destination, false);
                    
                    offset += levelSize;
                    levelWidth = max2(1, levelWidth / 2);
                    levelHeight = max2(1, levelHeight / 2);
                }
            }
            
            SDL_EndGPUCopyPass(texCopyPass);
        }
        else
        {
            uint offset = 0;
            uint levelWidth = buffer.size.width;
            uint levelHeight = buffer.size.height;
            
            SDL_GPUCopyPass* texCopyPass = SDL_BeginGPUCopyPass(texCopyCommandBuffer);
            
            for (uint mipLevel = 0; mipLevel < buffer.mipLevels; mipLevel++)
            {
                uint levelSize = levelWidth * levelHeight * buffer.format.pixelSize;
                
                SDL_GPUTextureTransferInfo source = {
                    transfer_buffer: texTransferBuffer,
                    offset: offset,
                };
                SDL_GPUTextureRegion destination = {
                    texture: texture,
                    mip_level: mipLevel,
                    layer: 0,
                    x: 0,
                    y: 0,
                    z: 0,
                    w: levelWidth,
                    h: levelHeight,
                    d: buffer.size.depth,
                };
                SDL_UploadToGPUTexture(texCopyPass, &source, &destination, false);
                
                offset += levelSize;
                levelWidth = max2(1, levelWidth / 2);
                levelHeight = max2(1, levelHeight / 2);
            }
            
            SDL_EndGPUCopyPass(texCopyPass);
        }
        
        if (options.generateMipmaps && !buffer.format.isCompressed)
            SDL_GenerateMipmapsForGPUTexture(texCopyCommandBuffer, texture);
        
        SDL_SubmitGPUCommandBuffer(texCopyCommandBuffer);
        SDL_ReleaseGPUTransferBuffer(gpu.device, texTransferBuffer);
        
        // TODO: customization via TextureCreationOptions
        SDL_GPUSamplerCreateInfo samplerCreateInfo;
        samplerCreateInfo.min_filter = SDL_GPU_FILTER_LINEAR;
        samplerCreateInfo.mag_filter = SDL_GPU_FILTER_LINEAR;
        samplerCreateInfo.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_LINEAR;
        if (options.repeatUV)
        {
            samplerCreateInfo.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
            samplerCreateInfo.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
            samplerCreateInfo.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
        }
        else
        {
            samplerCreateInfo.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
            samplerCreateInfo.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
            samplerCreateInfo.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        }
        samplerCreateInfo.mip_lod_bias = 0.0f;
        samplerCreateInfo.max_anisotropy = 16.0f;
        samplerCreateInfo.compare_op = SDL_GPU_COMPAREOP_ALWAYS;
        samplerCreateInfo.min_lod = 0.0f;
        samplerCreateInfo.max_lod = mipLevels - 1;
        samplerCreateInfo.enable_anisotropy = true;
        samplerCreateInfo.enable_compare = false;
        sampler = SDL_CreateGPUSampler(gpu.device, &samplerCreateInfo);
        if (sampler is null)
            return false;
        
        valid = true;
        return valid;
    }
}
