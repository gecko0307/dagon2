module dagon.render.deferred.gbuffer;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.image.color;

import dagon.core.sdl3;
import dagon.core.gpu;

class GBuffer: Owner
{
    GPU gpu;
    SDL_GPUColorTargetDescription[6] colorTargetsDescription;
    SDL_GPUColorTargetInfo[6] colorTargetsInfo;
    SDL_GPUDepthStencilTargetInfo depthStencilTargetInfo;
    Color4f colorBufferClearColor = Color4f(0.0f, 0.0f, 0.0f, 0.0f);
    
    SDL_GPUTexture* depthBuffer;
    SDL_GPUTexture* colorBuffer;
    SDL_GPUTexture* normalBuffer;
    SDL_GPUTexture* roughnessMetallicBuffer;
    SDL_GPUTexture* emissionBuffer;
    SDL_GPUTexture* velocityBuffer;
    SDL_GPUTexture* radianceBuffer;
    SDL_GPUTexture* occlusionBuffer1;
    SDL_GPUTexture* occlusionBuffer2;
    SDL_GPUTexture* previousOcclusionBuffer;
    SDL_GPUTexture* currentOcclusionBuffer;
    
    SDL_GPUSampler* depthSampler;
    SDL_GPUSampler* colorSampler;
    
    this(GPU gpu, Owner owner)
    {
        super(owner);
        this.gpu = gpu;
        
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        
        createBuffers(drawableWidth, drawableHeight);
        
        SDL_GPUColorTargetBlendState blendState = {
            src_color_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
            dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
            color_blend_op: SDL_GPU_BLENDOP_ADD,
            src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
            dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
            alpha_blend_op: SDL_GPU_BLENDOP_ADD,
            color_write_mask: 0,
            enable_blend: false,
            enable_color_write_mask: false
        };
        
        // Depth/stencil target
        depthStencilTargetInfo.clear_depth = 1.0f;
        depthStencilTargetInfo.load_op = SDL_GPU_LOADOP_CLEAR;
        depthStencilTargetInfo.store_op = SDL_GPU_STOREOP_STORE;
        depthStencilTargetInfo.stencil_load_op = SDL_GPU_LOADOP_CLEAR;
        depthStencilTargetInfo.stencil_store_op = SDL_GPU_STOREOP_STORE;
        depthStencilTargetInfo.cycle = false;
        depthStencilTargetInfo.clear_stencil = 0;
        depthStencilTargetInfo.mip_level = 0;
        depthStencilTargetInfo.layer = 0;
        depthStencilTargetInfo.texture = depthBuffer;
        
        // Color target 0 - color buffer
        colorTargetsDescription[0].format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
        colorTargetsDescription[0].blend_state = blendState;
        colorTargetsInfo[0].clear_color = SDL_FColor(
            colorBufferClearColor.r,
            colorBufferClearColor.g,
            colorBufferClearColor.b,
            colorBufferClearColor.a);
        colorTargetsInfo[0].load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetsInfo[0].store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo[0].texture = colorBuffer;
        
        // Target 1 - normal buffer
        colorTargetsDescription[1].format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        colorTargetsDescription[1].blend_state = blendState;
        colorTargetsInfo[1].clear_color = SDL_FColor(0.0f, 0.0f, 0.0f, 0.0f);
        colorTargetsInfo[1].load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetsInfo[1].store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo[1].texture = normalBuffer;
        
        // Target 2 - roughness/metallic buffer
        colorTargetsDescription[2].format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
        colorTargetsDescription[2].blend_state = blendState;
        colorTargetsInfo[2].clear_color = SDL_FColor(0.0f, 0.0f, 0.0f, 0.0f);
        colorTargetsInfo[2].load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetsInfo[2].store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo[2].texture = roughnessMetallicBuffer;
        
        // Target 3 - emission buffer
        colorTargetsDescription[3].format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        colorTargetsDescription[3].blend_state = blendState;
        colorTargetsInfo[3].clear_color = SDL_FColor(0.0f, 0.0f, 0.0f, 0.0f);
        colorTargetsInfo[3].load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetsInfo[3].store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo[3].texture = emissionBuffer;
        
        // Target 4 - velocity buffer
        colorTargetsDescription[4].format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        colorTargetsDescription[4].blend_state = blendState;
        colorTargetsInfo[4].clear_color = SDL_FColor(0.0f, 0.0f, 0.0f, 0.0f);
        colorTargetsInfo[4].load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetsInfo[4].store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo[4].texture = velocityBuffer;
        
        // Target 5 - radiance buffer
        colorTargetsDescription[5].format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        colorTargetsDescription[5].blend_state = blendState;
        colorTargetsInfo[5].clear_color = SDL_FColor(
            colorBufferClearColor.r,
            colorBufferClearColor.g,
            colorBufferClearColor.b,
            1.0f);
        colorTargetsInfo[5].load_op = SDL_GPU_LOADOP_CLEAR;
        colorTargetsInfo[5].store_op = SDL_GPU_STOREOP_STORE;
        colorTargetsInfo[5].texture = radianceBuffer;
        
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
        
        depthSampler = SDL_CreateGPUSampler(gpu.device, &samplerCreateInfo);
        colorSampler = SDL_CreateGPUSampler(gpu.device, &samplerCreateInfo);
    }
    
    ~this()
    {
        releaseBuffers();
        
        if (depthSampler)
            SDL_ReleaseGPUSampler(gpu.device, depthSampler);
        if (colorSampler)
            SDL_ReleaseGPUSampler(gpu.device, colorSampler);
    }
    
    void releaseBuffers()
    {
        if (depthBuffer)
            SDL_ReleaseGPUTexture(gpu.device, depthBuffer);
        if (colorBuffer)
            SDL_ReleaseGPUTexture(gpu.device, colorBuffer);
        if (normalBuffer)
            SDL_ReleaseGPUTexture(gpu.device, normalBuffer);
        if (roughnessMetallicBuffer)
            SDL_ReleaseGPUTexture(gpu.device, roughnessMetallicBuffer);
        if (emissionBuffer)
            SDL_ReleaseGPUTexture(gpu.device, emissionBuffer);
        if (velocityBuffer)
            SDL_ReleaseGPUTexture(gpu.device, velocityBuffer);
        if (radianceBuffer)
            SDL_ReleaseGPUTexture(gpu.device, radianceBuffer);
        if (occlusionBuffer1)
            SDL_ReleaseGPUTexture(gpu.device, occlusionBuffer1);
        if (occlusionBuffer2)
            SDL_ReleaseGPUTexture(gpu.device, occlusionBuffer2);
    }
    
    void createBuffers(uint width, uint height)
    {
        releaseBuffers();
        
        SDL_GPUTextureCreateInfo textureCreateInfo = {
            type: SDL_GPU_TEXTURETYPE_2D,
            width: width,
            height: height,
            layer_count_or_depth: 1,
            num_levels: 1,
            sample_count: SDL_GPU_SAMPLECOUNT_1
        };
        
        // Depth/stencil
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_D24_UNORM_S8_UINT;
        textureCreateInfo.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET;
        depthBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        depthStencilTargetInfo.texture = depthBuffer;
        
        // Color
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
        textureCreateInfo.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET,
        colorBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        colorTargetsInfo[0].texture = colorBuffer;
        
        // Normal
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        normalBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        colorTargetsInfo[1].texture = normalBuffer;
        
        // Roughness-metallic
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
        roughnessMetallicBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        colorTargetsInfo[2].texture = roughnessMetallicBuffer;
        
        // Emission
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        emissionBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        colorTargetsInfo[3].texture = emissionBuffer;
        
        // Velocity
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        velocityBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        colorTargetsInfo[4].texture = velocityBuffer;
        
        // Radiance
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT;
        radianceBuffer = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        colorTargetsInfo[5].texture = radianceBuffer;
        
        // Occlusion
        textureCreateInfo.format = SDL_GPU_TEXTUREFORMAT_R16_FLOAT;
        textureCreateInfo.width = width / 2;
        textureCreateInfo.height = height / 2;
        occlusionBuffer1 = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        occlusionBuffer2 = SDL_CreateGPUTexture(gpu.device, &textureCreateInfo);
        
        currentOcclusionBuffer = occlusionBuffer1;
        previousOcclusionBuffer = occlusionBuffer2;
    }
    
    void resize(uint width, uint height)
    {
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        createBuffers(drawableWidth, drawableHeight);
    }
    
    void clearColor(Color4f color) @property
    {
        colorBufferClearColor = color;
        colorTargetsInfo[0].clear_color = SDL_FColor(
            colorBufferClearColor.r,
            colorBufferClearColor.g,
            colorBufferClearColor.b,
            colorBufferClearColor.a);
        Color4f linearColor = color.toLinear;
        colorTargetsInfo[5].clear_color = SDL_FColor(
            linearColor.r,
            linearColor.g,
            linearColor.b,
            1.0f);
    }
    
    void swapOcclusionBuffers()
    {
        if (currentOcclusionBuffer is occlusionBuffer1)
        {
            currentOcclusionBuffer = occlusionBuffer2;
            previousOcclusionBuffer = occlusionBuffer1;
        }
        else
        {
            currentOcclusionBuffer = occlusionBuffer1;
            previousOcclusionBuffer = occlusionBuffer2;
        }
    }
}
