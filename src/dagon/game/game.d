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
import dagon.game.basegame;
import dagon.game.world;
import dagon.render.deferred;

class Game: BaseGame
{
    CubemapRenderer cubemapRenderer;
    DeferredRenderer renderer;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        cubemapRenderer = New!CubemapRenderer(gpu, eventManager, SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT);
        renderer = New!DeferredRenderer(gpu, eventManager);
    }
    
    Texture generateCubemap(Texture inputEnvmap, uint resolution, Owner cubemapOwner)
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
            generateMipmaps: false,
            repeatUV: false
        };
        
        Texture cubemap1 = New!Texture(gpu, null);
        cubemap1.create(&buffer, &options);
        cubemapRenderer.generateCubemap(inputEnvmap, cubemap1);
        
        buffer.mipLevels = 1 + cast(uint)floor(log2(cast(double)buffer.size.width));
        Texture cubemap2 = New!Texture(gpu, cubemapOwner);
        cubemap2.create(&buffer, &options);
        
        cubemapRenderer.prefilterCubemap(cubemap1, cubemap2);
        
        Delete(cubemap1);
        
        return cubemap2;
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
