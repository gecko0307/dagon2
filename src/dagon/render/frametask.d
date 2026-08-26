module dagon.render.frametask;

import dlib.core.ownership;

import dagon.core.sdl3;
import dagon.core.time;
import dagon.render.renderer;

/*
 * FrameTask allows to insert custom GPU commands
 * to the command buffer in the renderer.
 * You can use it, for example, to update textures
 * or meshes in real time.
 */
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
