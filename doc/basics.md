# Dagon Basics

## Engine Architecture

Dagon application is built on several API layers:
- **World** - User-defined game logics. Dagon follows Inversion of Control principle: user logics happen in event handlers that are called automatically by the core framework. The world is managed by the `Game` class.
- **Application** - Root-level object of the engine. It manages the game window and the main loop, does basic game configuration, loads and initializes shared libraries and performs other low-level tasks.
- **Game Subsystems** - Built-in managers. These include event manager, renderer, resource cache, shader compiler, scripting engine, physics engine, etc.
- **Graphics** - Graphical data that include entities, meshes, materials, textures and specialized abstractions (lights, decals, shadow maps). The game creates and configures them to build virtual 3D worlds.
- **SDL GPU / Vulkan** - GPU abstraction. User code is not required to work with the GPU directly, becase Dagon provides high-level API to create 3D objects, although this is necessary to extend the engine.
- **SDL** - Low-level multimedia framework that talks to the operating system. This layer abstracts platform-specific details such as window management and input handling.

## Game and World

At the root of an application hierarchy there is an `Application` object. Usually you'll want to use its more feature-rich derived class, `Game`. Typical use case is to make a custom game class that derives from `Game` and encapsulates your worlds:

```d
import dagon;

class MyGame: Game
{
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        MyWorld world = New!MyWorld(this);
        world.activate();
    }
}
```

In the `main` function you create an instance of `MyGame` and call `run` method:

```d
void main(string[] args)
{
    MyGame game = New!MyGame(1280, 720, "Window Title", args);
    game.run();
    Delete(game);
}
```

Window parameters that are passed to the game class are default ones which can be overridden by the user via the `setting.conf` file. See "Conf Files.md" for details.

Note that Dagon doesn't use D's built-in memory allocator (`new` operator), instead it allocates all its data with `New` and `Delete` functions from `dlib.core.memory`. You are also expected to do so. You still can use garbage collected data in Dagon, but this may result in weird bugs, so you are strongly recommended to do things our way. Most part of the engine is built around dlib's ownership model—every object belongs to some other object (owner), and deleting the owner will delete all of its owned objects. This allows semi-automatic memory management—you have to manually delete only root owner, which usually is a game object.

Most user-defined logic happen in `World` objects. A world object is responsible for managing resources and running user code for a self-contained part of the game: a level, cutscene, main menu, etc. At any given time, only one world can be active. World runs code in real time to react to user input and modify game state. World also manages one or more scenes that, in turn, are hierarchies of game entities.

Worlds are where you actually implement most part of your game. Similarly to a `Game`, you have to define your own worlds that derive from standard `World` class:

```d
class MyWorld: World
{
    MyGame game;

    this(MyGame game)
    {
        super(game);
        this.game = game;
    }

    // Override World methods...
}
```

You have a great control over the logic of your worlds thanks to method overriding. World can react to user input events, such as keyboard, mouse and joystick events:

```d
override void onKeyDown(int key)
{
    if (key == KEY_ESCAPE)
        application.exit();
}

override void onKeyUp(int key) { }
override void onMouseButtonDown(int button) { }
override void onMouseButtonUp(int button) { }

override void onGamepadButtonDown(uint deviceIndex, int button)
{
    if (button == GB_A)
    {
        // do something...
    }
}

// Override any other event handler from `EventListener`
```

## Scene

A scene is a storage for game objects (which are called entities). Dagon supports a hierarchical scene graph for managing entities:

```
Scene (root)
├── Entity (static environment)
├── Entity (dynamic object)
│   └── Entity (attached child)
└── Entity (camera/light)
```

Each entity can have:
- TRS transformation (position, rotation, scale)
- Drawable (visual geometry; usually a triangle mesh)
- Material (a set of properties describing a surface)
- Controller (an object that drives entity state updates)
- Child entities.

TODO: scene creation example

## The Game Loop

Every frame follows this sequence:
- Event dispatch. Processes SDL events like keyboard, mouse, or gamepad input, and custom events;
- Update. Calls `update` method for everything that should be updated per-frame. Updates are fixed, usually at 60 Hz rate, but this can be configured. Update is where entities recalculate their transformation matrices; 
- Post-update. This is used in cases when some controller logic depend on up-to-date global state (like camera following and transformation constraints);
- Render. The engine fills a command buffer and submits it to the GPU for asynchronous processing.

## Best Practices

1. **Use delta time** for all movement and physics calculations
2. **Organize entities** hierarchically for complex objects
3. **Cache assets** - load once and reuse. Share materials and textures across many entities
4. **Separate logic** - keep update from rendering.
