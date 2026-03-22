module dagon.render.deferred.renderer;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.image.color;

import dagon.core.gpu;
import dagon.core.logger;
import dagon.core.event;
import dagon.core.time;
import dagon.graphics.texture;
import dagon.resource.texture;
import dagon.render.renderer;
import dagon.render.deferred.gbuffer;
import dagon.render.deferred.passes.geometry;
import dagon.render.deferred.passes.ssao;
import dagon.render.deferred.passes.ssaodenoise;
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
    GBuffer gbuffer;
    PostProcessingContext ppContext;
    GeometryPass geometryPass;
    SSAOPass ssaoPass;
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
        ssaoPass = New!SSAOPass(this, gbuffer);
        ambientPass = New!AmbientPass(this, gbuffer);
        selfIlluminationPass = New!SelfIlluminationPass(this, gbuffer);
        sunLightPass = New!SunLightPass(this, gbuffer);
        // TODO: light volume pass
        tonemappingPass = New!TonemappingPass(this, ppContext);
        fxaaPass = New!FXAAPass(this, ppContext);
        sharpeningPass = New!SharpeningPass(this, ppContext);
        presentPass = New!PresentPass(this, ppContext);
    }
    
    void clearColor(Color4f color) @property
    {
        gbuffer.clearColor = color;
    }
    
    override void onUpdate(Time t)
    {
        // Temporary: currently we only need gamma-correction in tonemapper for FXAA
        tonemappingPass.tonemappingShader.enableGammaCorrection = fxaaPass.active;
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
