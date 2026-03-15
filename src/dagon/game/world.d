module dagon.game.world;

import dlib.core.ownership;

import dagon.core.event;
import dagon.core.time;
import dagon.core.gpu;
import dagon.graphics.scene;
import dagon.game.basegame;

class World: EventListener
{
    BaseGame baseGame;
    GPU gpu;
    Scene scene;
    
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
    
    void update(Time t)
    {
        processEvents();
        onUpdate(t);
        updateControllers(t);
        onPostUpdate(t);
    }
    
    void updateControllers(Time t)
    {
        foreach(entity; scene.entities)
        {
            if (entity.controller)
                entity.controller.update(t);
        }
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
