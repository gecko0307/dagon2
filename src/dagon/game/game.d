module dagon.game.game;

import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;

import dagon.core.application;
import dagon.core.sdl3;
import dagon.core.time;
import dagon.graphics.texture;
import dagon.graphics.envmap;
import dagon.graphics.brdflut;
import dagon.game.basegame;
import dagon.game.world;
import dagon.render.deferred;

struct IBLData
{
    Texture irradianceCubemap;
    Texture radianceCubemap;
    Texture brdfLUT;
}

class Game: BaseGame
{
    CubemapRenderer cubemapRenderer;
    BRDFLUTRenderer brdflutRenderer;
    DeferredRenderer renderer;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        cubemapRenderer = New!CubemapRenderer(gpu, eventManager, SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT);
        brdflutRenderer = New!BRDFLUTRenderer(gpu, eventManager, SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT);
        renderer = New!DeferredRenderer(gpu, eventManager);
    }
    
    IBLData generateCubemaps(Texture inputEnvmap, uint resolution, Owner cubemapsOwner)
    {
        TextureBuffer buffer = {
            format: {
                type: SDL_GPU_TEXTURETYPE_CUBE,
                format: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT,
                blockSize: 0,
                cubeFaces: CubeFaceBit.All,
                numChannels: 4,
                pixelSize: 8
            },
            size: {
                width: resolution,
                height: resolution,
                depth: 1
            },
            mipLevels: 1,
            data: []
        };
        
        TextureCreationOptions options = {
            generateMipmaps: true,
            repeatUV: false,
            anisotropicFiltering: false
        };
        
        Texture inputCubemap = New!Texture(gpu, null);
        inputCubemap.create(&buffer, &options);
        cubemapRenderer.generateCubemap(inputEnvmap, inputCubemap);
        
        options.generateMipmaps = false;
        
        TextureBuffer irrBuffer = buffer;
        irrBuffer.size.width = 64;
        irrBuffer.size.height = 64;
        Texture irradianceCubemapCoarse = New!Texture(gpu, null);
        irradianceCubemapCoarse.create(&irrBuffer, &options);
        cubemapRenderer.prefilterCubemapIrradiance(inputCubemap, irradianceCubemapCoarse);
        
        Texture irradianceCubemap = New!Texture(gpu, cubemapsOwner);
        irradianceCubemap.create(&irrBuffer, &options);
        cubemapRenderer.prefilterCubemapIrradiance(irradianceCubemapCoarse, irradianceCubemap);
        
        buffer.mipLevels = 1 + cast(uint)floor(log2(cast(double)buffer.size.width));
        Texture radianceCubemap = New!Texture(gpu, cubemapsOwner);
        radianceCubemap.create(&buffer, &options);
        
        cubemapRenderer.prefilterCubemap(inputCubemap, radianceCubemap);
        
        Delete(irradianceCubemapCoarse);
        Delete(inputCubemap);
        
        return IBLData(irradianceCubemap, radianceCubemap, renderer.brdfLUT);
    }
    
    Texture generateBRDFLUT(uint resolution, Owner textureOwner)
    {
        TextureBuffer buffer = {
            format: {
                type: SDL_GPU_TEXTURETYPE_2D,
                format: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT,
                blockSize: 0,
                cubeFaces: CubeFaceBit.None,
                numChannels: 4,
                pixelSize: 8
            },
            size: {
                width: resolution,
                height: resolution,
                depth: 1
            },
            mipLevels: 1,
            data: []
        };
        
        TextureCreationOptions options = {
            generateMipmaps: false,
            repeatUV: false,
            anisotropicFiltering: false
        };
        
        Texture brdfLut = New!Texture(gpu, textureOwner);
        brdfLut.create(&buffer, &options);
        
        brdflutRenderer.generateTexture(brdfLut);
        
        return brdfLut;
    }
    
    override void onUpdate(Time t)
    {
        super.onUpdate(t);
        if (activeWorld)
            renderer.setScene(activeWorld.scene);
        renderer.update(t);
    }
    
    override void onRender()
    {
        renderer.render();
    }
}
