module dagon.render.renderer;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.container.array;

import dagon.core.sdl3;
import dagon.core.gpu;
import dagon.core.logger;
import dagon.core.event;
import dagon.core.time;
import dagon.core.updateable;
import dagon.graphics.state;
import dagon.graphics.shapes;
import dagon.graphics.material;
import dagon.graphics.scene;
import dagon.render.view;
import dagon.render.pass;

abstract class Renderer: EventListener, Updateable
{
    GPU gpu;
    SDL_GPUCommandBuffer* commandBuffer;
    Array!RenderPass renderPasses;
    ShapeNormQuad screenQuad;
    GraphicsState state;
    View view;
    Material defaultMaterial;
    bool active = true;
    
    this(GPU gpu, EventManager eventManager)
    {
        super(eventManager, gpu);
        this.gpu = gpu;
        this.screenQuad = New!ShapeNormQuad(gpu, this);
        
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        this.view = New!View(drawableWidth, drawableHeight, this);
        
        defaultMaterial = New!Material(this);
    }
    
    ~this()
    {
        renderPasses.free();
    }
    
    void addRenderPass(RenderPass renderPass)
    {
        renderPasses.append(renderPass);
        renderPass.view = view;
    }
    
    void render()
    {
        if (!active)
            return;
        
        state.reset();
        
        commandBuffer = SDL_AcquireGPUCommandBuffer(gpu.device);
        
        foreach(i, pass; renderPasses)
        {
            if (pass.active)
            {
                state.pass = pass;
                pass.render(&state);
            }
        }
        
        SDL_SubmitGPUCommandBuffer(commandBuffer);
    }
    
    void update(Time t)
    {
        processEvents();
        
        if (state.scene)
        {
            view.camera = state.scene.activeCamera;
        }
        
        view.update(t);
        
        state.time = t;
        
        onUpdate(t);
    }
    
    void onUpdate(Time t)
    {
        //
    }
    
    override void onResize(int width, int height)
    {
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        view.resize(drawableWidth, drawableHeight);
        
        foreach(pass; renderPasses)
        {
            pass.resize(drawableWidth, drawableHeight);
        }
    }
    
    override void onMinimize()
    {
        active = false;
    }
    
    override void onRestore()
    {
        active = true;
    }
    
    void setScene(Scene scene)
    {
        state.scene = scene;
    }
    
    void renderScreenQuad(GraphicsState* state)
    {
        screenQuad.render(state);
    }
}
