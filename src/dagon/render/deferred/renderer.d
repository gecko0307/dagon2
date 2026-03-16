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
import dagon.render.postprocessing.context;
import dagon.render.postprocessing.passes.tonemapping;
import dagon.render.postprocessing.passes.fxaa;
import dagon.render.postprocessing.passes.sharpening;
import dagon.render.postprocessing.passes.present;

class DeferredRenderer: Renderer
{
    Texture brdfLUT;
    GBuffer gbuffer;
    PostProcessingContext ppContext;
    GeometryPass geometryPass;
    AmbientPass ambientPass;
    SelfIlluminationPass selfIlluminationPass;
    SunLightPass sunLightPass;
    TonemappingPass tonemappingPass;
    FXAAPass fxaaPass;
    SharpeningPass sharpeningPass;
    PresentPass presentPass;
    
    this(GPU gpu, EventManager eventManager)
    {
        super(gpu, eventManager);
        gbuffer = New!GBuffer(gpu, this);
        ppContext = New!PostProcessingContext(gpu, gbuffer, this);
        
        // TODO: sun shadow pass
        geometryPass = New!GeometryPass(this, gbuffer);
        ambientPass = New!AmbientPass(this, gbuffer);
        selfIlluminationPass = New!SelfIlluminationPass(this, gbuffer);
        sunLightPass = New!SunLightPass(this, gbuffer);
        // TODO: light volume pass
        tonemappingPass = New!TonemappingPass(this, ppContext);
        fxaaPass = New!FXAAPass(this, ppContext);
        sharpeningPass = New!SharpeningPass(this, ppContext);
        presentPass = New!PresentPass(this, ppContext);
        
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
        ppContext.resize(drawableWidth, drawableWidth);
        super.onResize(width, height);
    }
}
