# Getting Started with Dagon 2

This guide will walk you through installing Dagon and creating your first project.

## Prerequisites
Before installing Dagon, ensure you have:

1. **D Language Compiler**. Download from [dlang.org](https://dlang.org/download.html). LDC (LLVM D Compiler) is recommended for best performance.
2. **DUB Package Manager**. Comes with all official D distributions.
3. **Vulkan runtime**. It is provided by the graphics card vendor as part of the driver.

Compile-time dependencies are fully managed with DUB. Runtime dependencies (SDL3, SDL3_Image, FreeType, GLSLang, SPIRV-Cross, libktx, Jolt) are provided with Dagon and automatically copied to the project when building with DUB.

## Project Structure

Create a new project with the following layout:

```
myproject/
├── dub.json
├── source/
│   └── main.d
├── assets/
│   └── (game assets go here)
├── settings.conf
└── render.conf
```

### DUB Configuration

Create `dub.json`:

```json
{
    "name": "myproject",
    "description": "My first Dagon game",
    "license": "proprietary",
    "authors": ["Your Name"],
    "dependencies": {
        "dagon2": "~>2.0.0-alpha1"
    }
}
```

### Application Code

Create `source/main.d`:

```d
import dagon;

class MyWorld: World
{
    MyGame game;

    this(MyGame game)
    {
        super(game);
        this.game = game;

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

        auto ePlane = scene.addEntity();
        ePlane.drawable = New!ShapePlane(10, 10, 1, gpu, this);
    }

    override void onUpdate(Time t) { }
    override void onPostUpdate(Time t) { }
    override void onKeyDown(int key) { }
    override void onKeyUp(int key) { }
    override void onTextInput(dchar code) { }
    override void onMouseButtonDown(int button) { }
    override void onMouseButtonUp(int button) { }
    override void onMouseWheel(float x, float y) { }
    override void onControllerButtonDown(uint deviceIndex, int btn) { }
    override void onControllerButtonUp(uint deviceIndex, int btn) { }
    override void onControllerAxisMotion(uint deviceIndex, int axis, float value) { }
    override void onResize(int width, int height) { }
    override void onFocusLoss() { }
    override void onFocusGain() { }
    override void onDropFile(string filename) { }
    override void onKeyboardLayoutChange() { }
    override void onUserEvent(int code, void* payload) { }
    override void onQuit() { }
}

class MyGame: Game
{
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        MyWorld world = New!MyWorld(this);
        world.activate();
    }
}

void main()
{
    MyGame game = New!MyGame(1280, 720, false, "Dagon Demo", args);
    game.run();
    Delete(game);
}
```

## Configuration Files

### settings.conf

General engine settings:

```
log.enabled: true;
log.level: "debug";
log.toStdout: true;
log.file: "demo.log";

vfs.appDataFolder: ".myproject";

window.width: 1280;
window.height: 720;
window.x: "auto";
window.y: "auto";
window.resizable: true;
window.title: "Dagon Demo";

fullscreen: false;
vsync: 0;
updatesPerSecond: 60;
supersampling: 1;
hideConsole: false;

locale: "en_US";

gpu.debugOutput: true;
gpu.outputColorProfile: "Gamma22";
gpu.anisotropicFiltering: true;
gpu.defaultTextureAnisotropy: 16;
```

### render.conf

Controls rendering and post-processing settings:

```
ssao.enabled: true;
motionBlur.enabled: true;
tonemapping.enabled: true;
fxaa.enabled: true;
sharpening.enabled: true;
```

## Compile and Run

```bash
dub build
./myproject
```

Congratulations! You now have a Dagon application running.

## Development Workflow

A typical development session:

1. **Define your game structure** in the `Game` subclass
2. **Create one or more worlds** using `World` subclasses
2. **Load assets**
3. **Update game logic** in `onUpdate` method
4. **Handle user input** in event handler methods.

See [Game Subsystems](game-subsystems.md) for details on the game loop and lifecycle.

## Next Steps

- Read [Core Concepts](core-concepts.md) to understand the engine architecture
- Follow the [Hello World Tutorial](tutorials/01-hello-world.md) for hands-on learning
- Check out the `demo/` folder for a complete example project
