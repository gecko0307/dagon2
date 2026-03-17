module dagon.game.game;

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
    DeferredRenderer renderer;
    CubemapRenderer cubemapRenderer;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        renderer = New!DeferredRenderer(gpu, eventManager);
        cubemapRenderer = New!CubemapRenderer(gpu, eventManager, SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT);
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
        
        Texture outputCubemap = New!Texture(gpu, cubemapOwner);
        outputCubemap.create(&buffer, &options);
        cubemapRenderer.generateCubemap(inputEnvmap, outputCubemap);
        return outputCubemap;
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
