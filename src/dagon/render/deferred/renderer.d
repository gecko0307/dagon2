module dagon.render.deferred.renderer;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.image.color;

import dagon.core.gpu;
import dagon.core.logger;
import dagon.core.event;
import dagon.graphics.texture;
import dagon.resource.texture;
import dagon.render.renderer;
import dagon.render.deferred.gbuffer;
import dagon.render.deferred.passes.geometry;
import dagon.render.deferred.passes.ambient;
import dagon.render.deferred.passes.selfillumination;
import dagon.render.deferred.passes.sunlight;
import dagon.render.deferred.passes.present;

class DeferredRenderer: Renderer
{
    Texture brdfLUT;
    GBuffer gbuffer;
    GeometryPass geometryPass;
    AmbientPass ambientPass;
    SelfIlluminationPass selfIlluminationPass;
    SunLightPass sunLightPass;
    PresentPass presentPass;
    
    this(GPU gpu, EventManager eventManager)
    {
        super(gpu, eventManager);
        gbuffer = New!GBuffer(gpu, this);
        geometryPass = New!GeometryPass(this, gbuffer);
        ambientPass = New!AmbientPass(this, gbuffer);
        selfIlluminationPass = New!SelfIlluminationPass(this, gbuffer);
        sunLightPass = New!SunLightPass(this, gbuffer);
        presentPass = New!PresentPass(this, gbuffer);
        
        string brdfLUTFilename = "data/__internal/textures/brdf.dds";
        TextureAsset brdfAsset = New!TextureAsset(gpu, this);
        brdfAsset.generateMipmaps = false;
        brdfAsset.repeatUV = false;
        auto istrm = gpu.application.vfs.openForInput(brdfLUTFilename);
        brdfAsset.load(brdfLUTFilename, istrm, gpu.application.vfs);
        Delete(istrm);
        
        brdfLUT = brdfAsset.texture;
        state.brdfLUT = brdfLUT;
        state.brdfLUTEnabled = true;
    }
    
    void clearColor(Color4f color) @property
    {
        gbuffer.clearColor = color;
    }
    
    override void onResize(int width, int height)
    {
        uint drawableWidth = gpu.application.drawableWidth;
        uint drawableHeight = gpu.application.drawableHeight;
        gbuffer.resize(drawableWidth, drawableWidth);
        super.onResize(width, height);
    }
}
