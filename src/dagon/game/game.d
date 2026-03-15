module dagon.game.game;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;

import dagon.core.application;
import dagon.core.time;
import dagon.game.basegame;
import dagon.game.world;
import dagon.render.deferred;

class Game: BaseGame
{
    DeferredRenderer renderer;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        renderer = New!DeferredRenderer(gpu, eventManager);
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
