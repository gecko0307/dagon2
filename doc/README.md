# Dagon 2

Dagon is a 3D game framework for D language. It features deferred HDR renderer, PBR materials, an event manager, scene manager, asset manager, and entity-component model. This guide will help you get started with building games and interactive applications using Dagon.

## The Name

Dagon is named after a god from H. P. Lovecraft's Cthulhu Mythos pantheon. This name was choosen in accordance with the community tradition of naming D projects using words beginning with 'D'.

## System Requirements

Realistic minimum system requirements (for Full HD rendering at 60 fps):
- CPU: Intel Core i3-10100 / AMD Ryzen 3 3100
- RAM: application-dependent, usually 8 Gb minimum
- GPU: Vulkan-capable, tested on GeForce RTX 3050
- VRAM: application-dependent, 6 Gb minimum
- OS: 64-bit Windows 10 or higher / Linux.

## Architecture

Dagon is a hierarchical component-based framework. At the root of the hierarchy there is an `Application` object. It can store one or multiple `World` objects. Each world has its own assets, logics, event listeners, etc. World manages game scenes and creates `Entity` objects which are basic building blocks of the game.

Read more [here](basics.md).

## dlib

Dagon heavily relies on [dlib](https://github.com/gecko0307/dlib). It is used everywhere in the engine, from memory management and vector math to file I/O and data containers.

## Memory Management

Dagon mostly avoids using the garbage collector and manages all of its data manually with `New` and `Delete` functions from dlib. You are also expected to do so. You still can use garbage collected data in Dagon, but this may result in weird bugs, so you are strongly recommended to do things our way. Most part of the engine is built around dlib's ownership model. Every object belongs to some other object (owner), and deleting the owner will delete all of its owned objects. This allows semi-automatic memory management. You have to manually delete only root owner, which usually is an `Application` object.

## Creating Assets

Dagon is a framework-style engine, meaning that it is controlled programmatically and doesn't provide you with an editor. How you will build your scenes is up to you. You can build them manually by loading models one by one in your code, create your own scene format, or export glTF scenes from a 3D editor of your choise. We recommend [Blender](https://www.blender.org/) as an external editor. Dagon 2 also implements its own asset format, [DAF](asset-format.md), with an exporter script for Blender 5.0.

## Module Structure

Dagon is organized around several packages:

|      Package     |                      Purpose                      |
|------------------|---------------------------------------------------|
| `dagon.core`     | Core application functionality, event handling    |
| `dagon.game`     | Game framework, world management, game logic      |
| `dagon.graphics` | Graphical primitives, textures, materials, meshes |
| `dagon.render`   | Rendering                                         |
| `dagon.resource` | Asset loaders, resource caching                   |
| `dagon.ui`       | User interface components                         |
| `dagon.jolt`     | Physics engine integration                        |
| `gscript`        | GScript3 virtual machine                          |

## Further reading

### Beginner topics:
- [Basics](basics.md) - Understand the basic Dagon application structure
- [Entity](entity.md) - Building scenes from basic transformable objects
- [Materials](materials.md) - Controlling the visual appearance of game objects
- [Resources](resources.md) - Loading and managing game assets
- [Textures](textures.md) - Using external images
- [Event System](event-system.md) - Handling user input and other OS events in the game
- [FAQ](FAQ.md)

### Intermediate topics:
- [Configuration](configuration.md) - Tweaking the engine in run time
- [Localization](localization.md) - Translating in-game text to user's language

### Advanced topics:
- [Rendering](rendering.md) - Render pipeline overview
- [Shaders](shaders.md) - GPU programming
- [Asset Format](asset-format.md) - Dagon's native 3D model format, DAF
- [Camera Controller](camera-controller.md) - Blending camera transformations
- [Physics](physics.md) - Jolt physics integration
- [Video](video.md) - Video playback using libVLC
- [Scripting](gscript/README.md) - Scripting with GScript3 language.
