module dagon.render.frametask;

import dlib.core.ownership;

import dagon.core.sdl3;
import dagon.core.time;
import dagon.render.renderer;

abstract class FrameTask: Owner
{
    bool active = true;
    
    this(Owner owner)
    {
        super(owner);
    }
    
    void update(Time t);
    void submit(Renderer renderer);
}
