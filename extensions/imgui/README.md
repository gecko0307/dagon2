# dagon2:imgui

Immediate mode GUI extension that uses [Dear ImGui](https://github.com/ocornut/imgui) via [cimgui](https://github.com/cimgui/cimgui) wrapper and a custom version of [i2d-imgui](https://github.com/Inochi2D/i2d-imgui) dynamic binding which is in turn a fork of [bindbc-imgui](https://github.com/playmer/bindbc-imgui).

Unlike in Dagon 1.x, cimgui library for Dagon 2 should be compiled without any backends and additions; all backend functionality is implemented on D side.

`thirdparty/bindbc-imgui-0.7.0` folder contains i2d-imgui and cimgui sources. To build cimgui:

1. Make sure [CMake](https://cmake.org/) is installed. Minimal required CMake version is 3.1
2. Go to [thirdparty/bindbc-imgui-0.7.0/deps/cimgui](https://github.com/gecko0307/dagon/tree/master/extensions/imgui/thirdparty/bindbc-imgui-0.7.0/deps/cimgui). Create `build` directory. Inside it, run `cmake -DCMAKE_BUILD_TYPE=Release ..`
3. Under Linux, run `make`. Under Windows, open and build generated Visual Studio project. You should get `Release/cimgui.dll` under Windows, or `cimgui.so` under Linux.

## Usage

```d
import dagon.ext.imgui;

class UI: ImGui
{
    this(Application application, Renderer renderer)
    {
        super(application, renderer);
    }
    
    override void onUpdate(Time t)
    {
        // Call ImGui functions here to draw your UI
    }
}

class MyGame: Game
{
    UI ui;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        
        ui = New!UI(this, renderer);
        eventManager.onProcessEvent = &ui.onProcessEvent;
    }
    
    override void onUpdate(Time t)
    {
        super.onUpdate(t);
        ui.update(t);
    }
}
```

Don't forget to load the library at the initialization phase, for example in the beginning of your `main` function:

```
ImGuiSupport imguiSupport = loadImGui();
```
