# Video

Dagon supports video playback via dagon:video extension which is based on libVLC, a free video framework which is part of the [VLC Media Player](https://github.com/videolan/vlc). It supports all popular video formats. The video is decoded to GPU texture and can be used in the engine just as any normal texture.

## Libraries and Plugins

The extension depends on `libvlccore.dll` and `libvlc.dll` (`libvlccore.so.9`, `libvlc.so` and `libidn.so.11` under Linux). Also a number of plugins are necessary for libVLC to work properly. They are stored in `plugins` folder under Windows and `plugins_linux` folder under Linux.

## Usage

Add `dagon2:video` package to project dependencies:

```
dub add dagon2:video
```

The extension provides two classes: `VideoManager` and `Video`. The underlying `Texture` object is available as `Video.texture` property. To open a video, call `Video.open`, to start playing—`Video.play`.

The following example applies a video texture to the 3D plane in the scene:

```d
import dagon;
import dagon.ext.video;

class MyWorld: World
{
    MyGame game;
    VideoManager videoManager;
    Video video;
    FrameTask videoUpdateTask;
    bool canPlayVideo = false;
    bool videoIsPlaying = false;
    
    this(MyGame game)
    {
        super(game);
        this.game = game;
        this.videoManager = game.videoManager;
    }
    
    override void afterLoad()
    {
        scene = New!Scene(gpu, this);
        scene.sun.pitch(-45.0f);
        scene.sun.energy = 10.0f;
        
        auto camera = scene.addCamera();
        auto freeview = New!FreeviewController(eventManager, camera);
        freeview.setZoom(5);
        freeview.setRotation(30.0f, -45.0f, 0.0f);
        freeview.translationStiffness = 0.25f;
        freeview.rotationStiffness = 0.25f;
        freeview.zoomStiffness = 0.25f;
        scene.activeCamera = camera;
        
        video = New!Video(videoManager, 1920, 1080, this);
        canPlayVideo = video.open("media/video.mp4");
        video.setVolume(0.5f);
        videoUpdateTask = game.renderer.addFrameTask(video); // to update the video texture every frame
        
        auto matVideo = addMaterial();
        matVideo.baseColorTexture = video.texture;
        matVideo.alphaTestThreshold = 0.0f;
        
        float videoAspectRatio = cast(float)videoWidth / cast(float)videoHeight;
        auto ePlane = scene.addEntity();
        ePlane.drawable = New!ShapePlane(10 * videoAspectRatio, 10, 1, gpu, this);
        ePlane.material = New!Material(this);
        ePlane.material.baseColorTexture = video.texture;
        ePlane.material.shadeless = true;
        
        if (canPlayVideo)
        {
            video.play();
            videoIsPlaying = true;
        }
    }
    
    override void onUpdate(Time t)
    {
        videoUpdateTask.active = videoIsPlaying;
        if (videoIsPlaying)
        {
            if (video.isEnded)
            {
                videoIsPlaying = false;
                // do something at the end of the playback
            }
        }
    }
}

class MyGame: Game
{
    VideoManager videoManager;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        videoManager = New!VideoManager(gpu, this);
        MyWorld world = New!MyWorld(this);
        world.activate();
    }
}

void main(string[] args)
{
    VLCSupport sup = loadVLC();
    
    MyGame game = New!MyGame(1280, 720, false, "Dagon video demo", args);
    game.run();
    Delete(game);
}
```
