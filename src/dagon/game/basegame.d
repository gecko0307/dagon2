module dagon.game.basegame;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;

import dagon.core.application;
import dagon.core.time;
import dagon.game.world;

class BaseGame: Application
{
    Array!World worlds;
    World activeWorld;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
    }
    
    ~this()
    {
        worlds.free();
    }
    
    World addWorld(World world)
    {
        worlds.append(world);
        return world;
    }
    
    override void onUpdate(Time t)
    {
        if (activeWorld)
            activeWorld.update(t);
    }
}
