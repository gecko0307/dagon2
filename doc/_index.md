# Dagon 2 Documentation
Welcome to Dagon 2! This guide will help you get started with building games and interactive applications using Dagon, a feature-rich 3D game development framework for the D programming language.

## Key Features
- **Vulkan-based rendering** with PBR
- **Scene graph** for hierarchical object management
- **Rigid body dynamics** powered by [Jolt Physics](https://github.com/jrouwe/JoltPhysics)
- **Asset pipeline** with extensive file format support
- **Scripting support** via [GScript3](https://github.com/gecko0307/gscript3)
- **Cross-platform** - Windows and Linux support
- **Virtual file system** for flexible asset organization

## Core Requirements
- [D compiler](https://dlang.org/download.html) (DMD or LDC)
- [DUB](https://github.com/dlang/dub/) (usually comes with the compiler)
- Vulkan 1.0 compatible graphics card with the latest driver
- SDL 3.4 (provided with the engine)

## Module Structure
Dagon is organized around several key packages:

| Package | Purpose |
|---------|---------|
| `dagon.core` | Core application functionality, event handling |
| `dagon.game` | Game framework, world management, game logic |
| `dagon.graphics` | Graphical primitives, textures, materials, meshes |
| `dagon.render` | Rendering |
| `dagon.resource` | Asset loaders, resource caching |
| `dagon.ui` | User interface components |
| `dagon.jolt` | Physics engine integration |
| `gscript` | GScript3 virtual machine |

## Quick Links
- [Getting Started](getting-started.md) - Installation and your first project
- [Core Concepts](core-concepts.md) - Understand the engine architecture
- [Resources](resources.md) - Loading and managing game assets
- [Shaders](shaders.md)
- [Rendering](rendering.md) - Rendering pipeline and visual features
- [Configuration](configuration.md) - Engine settings and configuration
- [Physics Engine](physics.md) - Jolt physics integration
- [Scripting](gscript/_index.md) - Scripting with GScript3 language

## Tutorials
TODO

---

**Last Updated:** 2026-04-30  
**Dagon Version:** 2.0 (in development)
