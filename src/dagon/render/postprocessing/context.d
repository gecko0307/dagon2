module dagon.render.postprocessing.context;

import dlib.core.ownership;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.logger;
import dagon.render.deferred.gbuffer;

enum PingPongBufferState
{
    Ping = 0,
    Pong = 1
}

class PostProcessingContext: Owner
{
    GPU gpu;
    GBuffer gbuffer;
    SDL_GPUTextureFormat bufferFormat;
    SDL_GPUTexture* buffer1;
    SDL_GPUTexture* buffer2;
    SDL_GPUTexture* writeBuffer;
    SDL_GPUTexture* readBuffer;
    SDL_GPUSampler* bufferSampler;
    PingPongBufferState bufferState = PingPongBufferState.Ping;
    
    this(GPU gpu, GBuffer gbuffer, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
        this.gbuffer = gbuffer;
        
        bufferFormat = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        
        createBuffers(drawableWidth, drawableHeight);
        
        SDL_GPUSamplerCreateInfo samplerCreateInfo = {
            min_filter: SDL_GPU_FILTER_LINEAR,
            mag_filter: SDL_GPU_FILTER_LINEAR,
            mipmap_mode: SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
            address_mode_u: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            address_mode_v: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            address_mode_w: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            mip_lod_bias: 0.0f,
            max_anisotropy: 1.0f,
            min_lod: 0.0f,
            max_lod: 0.0f,
            enable_anisotropy: false,
            enable_compare: false,
            compare_op: SDL_GPU_COMPAREOP_ALWAYS
        };
        
        bufferSampler = SDL_CreateGPUSampler(gpu.device, &samplerCreateInfo);
    }
    
    ~this()
    {
        releaseBuffers();
        
        if (bufferSampler)
            SDL_ReleaseGPUSampler(gpu.device, bufferSampler);
    }
    
    void releaseBuffers()
    {
        if (buffer1)
            SDL_ReleaseGPUTexture(gpu.device, buffer1);
        if (buffer2)
            SDL_ReleaseGPUTexture(gpu.device, buffer2);
    }
    
    void createBuffers(uint width, uint height)
    {
        releaseBuffers();
        
        SDL_GPUTextureCreateInfo textureCreateInfo = {
            type: SDL_GPU_TEXTURETYPE_2D,
            format: bufferFormat,
            usage: SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET,
            width: width,
            height: height,
            layer_count_or_depth: 1,
            num_levels: 1,
            sample_count: SDL_GPU_SAMPLECOUNT_1
        };
        
        buffer1 = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        buffer2 = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        writeBuffer = buffer1;
        readBuffer = buffer2;
        bufferState = PingPongBufferState.Ping;
    }
    
    void resize(uint width, uint height)
    {
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        createBuffers(drawableWidth, drawableHeight);
    }
    
    void swapTargets()
    {
        if (bufferState == PingPongBufferState.Ping)
        {
            writeBuffer = buffer2;
            readBuffer = buffer1;
            bufferState = PingPongBufferState.Pong;
        }
        else
        {
            writeBuffer = buffer1;
            readBuffer = buffer2;
            bufferState = PingPongBufferState.Ping;
        }
    }
}
