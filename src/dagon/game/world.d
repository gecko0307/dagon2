module dagon.game.world;

import dlib.core.memory;
import dlib.core.ownership;

import dagon.core.event;
import dagon.core.time;
import dagon.core.gpu;
import dagon.graphics.texture;
import dagon.graphics.scene;
import dagon.game.basegame;
//import dagon.resource.asset;
import dagon.resource.image;
import dagon.resource.texture;

class World: EventListener
{
    BaseGame baseGame;
    GPU gpu;
    Scene scene;
    bool recalculateMatrices = true;
    
    this(BaseGame baseGame)
    {
        super(baseGame.eventManager, baseGame);
        this.baseGame = baseGame;
        this.gpu = baseGame.gpu;
    }
    
    void activate()
    {
        baseGame.activeWorld = this;
    }
    
    // TODO: move to AssetManager
    TextureAsset loadTexture(string filename, ImageConversionOptions* conversionOptions, TextureCreationOptions* creationOptions, bool cache = true)
    {
        TextureAsset asset = New!TextureAsset(gpu, this);
        asset.conversionOptions = *conversionOptions;
        asset.creationOptions = *creationOptions;
        asset.cache = cache;
        asset.load(filename, baseGame.vfs);
        return asset;
    }
    
    // TODO: move to AssetManager
    T loadAsset(T)(string filename)
    {
        T asset = New!T(gpu, this);
        auto istrm = baseGame.vfs.openForInput(filename);
        asset.load(filename, istrm, baseGame.vfs);
        Delete(istrm);
        return asset;
    }
    
    void update(Time t)
    {
        processEvents();
        onUpdate(t);
        foreach(entity; scene.entities)
        {
            entity.update(t);
        }
        onPostUpdate(t);
    }
    
    void onUpdate(Time t)
    {
        //
    }
    
    void onPostUpdate(Time t)
    {
        //
    }
}
