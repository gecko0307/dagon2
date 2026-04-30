# Core Concepts

Understanding Dagon's architecture and design principles will help you build better applications.

## Engine Architecture

Dagon application is built on several API layers:
* **World** - User-defined game logics. Dagon follows Inversion of Control principle: user logics happen in event handlers that are called automatically by the core framework.
* **Game Subsystems** - Built-in managers. These include event manager, renderer, asset manager, shader compiler, scene hierarchy, scripting engine, physics engine, etc. User code works with them directly.
* **Graphics** - Graphical data that include entities, meshes, materials, textures and specialized abstractions (lights, decals, shadow maps). The game creates and configures them to build virtual 3D worlds.
* **SDL GPU / Vulkan** - GPU abstraction. User code is not required to work with the GPU directly, becase Dagon provides high-level API to create virtual worlds, although this is necessary to extend the engine.
* **SDL** - Low-level multimedia framework that talks to the operating system. This layer abstracts platform-specific details such as window management and input handling.

## Core Concepts

### Game Class

The `Game` class is a standard entry point. Inherit from it to create your own application:

```d
class MyGame: Game
{
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
    }
}
```

### World
A `World` object is a game mechanic unit. It is responsible for managing resources and running logic for a self-contained part of the game: level, cutscene, main menu, etc. At any given time, only one world can be active. World is an event listener, it runs code in real time to react to user input and modify game state. World also manages one or more scenes that, in turn, are hierarchies of game entities.

Worlds are where you actually implement most part of your game.

TODO: example of a world

### Scene
Dagon supports a hierarchical scene graph for managing game entities:

```
Scene (root)
├── Entity (static environment)
├── Entity (dynamic object)
│   └── Entity (attached child)
└── Entity (camera/light)
```

Each entity can have:
- TRS transformation (position, rotation, scale)
- Drawable (visual geometry; usually an indexed triangle mesh) and material
- Controller (an object that drives entity state updates)
- Child entities.

## The Game Loop
Every frame follows this sequence:

- Event dispatch. Process SDL events like keyboard, mouse, or gamepad input, and custom events;
- Update. Calls `update` method for everything that should be updated per-frame. Updates are fixed, usually at 60 Hz rate, but this can be configured. Update is where entities recalculate their transformation matrices; 
- Post-update. This is used in cases when some controller logic depend on up-to-date global state (like camera following and transformation constraints);
- Render. The engine fills a command buffer and submits it to the GPU for asynchronous processing.

## Event System

Dagon provides event handling for user input. Any object can become an event listener by inheriting from `EventListener` class:

```d
override void onKeyDown(int key)
{
    if (key == KEY_RETURN)
    {

    }
}

override void onGamepadButtonDown(uint deviceIndex, int button)
{
    if (button == GB_A)
    {

    }
}
```

## Best Practices
1. **Use delta time** for all movement and physics calculations
2. **Organize entities** hierarchically for complex objects
3. **Cache assets** - load once and reuse. Share materials and textures across many entities
4. **Separate logic** - keep update from rendering
6. **Profile regularly** - use the performance counters
