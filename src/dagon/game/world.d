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
    
    void update(Time t)
    {
        processEvents();
        onUpdate(t);
        if (recalculateMatrices)
        {
            foreach(entity; scene.entities)
            {
                if (entity.controller)
                    entity.controller.update(t);
                else
                    entity.update(t);
            }
            
            recalculateMatrices = false;
        }
        else
        {
            foreach(entity; scene.entities)
            {
                if (entity.autoUpdate)
                    entity.update(t);
                else if (entity.controller)
                    entity.controller.update(t);
            }
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
