# Configuration

This guide covers Dagon's built-in configuration system for runtime settings and rendering parameters. The engine uses *.conf files to store user-controllable settings.

## Syntax

Conf file consists of key-value pairs separated by semicolon:

```
optionName: optionValue;
```

optionValue can be a number, a boolean value, a vector (an array), a double-quoted string, or an identifier:

```
numberOption: 10;
boolOption: true;
vectorOption: [0.5, 1.0, 1.0];
stringOption: "Some text";
copyOption: numberOption;
```

Boolean `false` is the same as number `0`, `true` is the same as `1`.

Lines beginning with double slash (`//`) are treated as comments and ignored:

```
// Some comment
```

## Built-in Conf Files

Dagon recognizes a number of built-in *.conf files (`settings.conf`, `render.conf`, `input.conf`, `audio.conf`) that are loaded from each VFS-mounted path. User-defined *.conf files (in APPDATA and custom paths) override root ones (in executable directory).

Built-in *.conf files are fully reserved for Dagon's internal mechanisms, and it is not recommended to use them for storing game-specific settings. The engine doesn't modify them, so you can implement a visual configurator in your game that modifies these files.

### settings.conf

`settings.conf` contains runtime settings recognozed by the `Application` class. If the file doesn't exist, the engine will print a warning and run with default settings.

Log settings:

* `log.enabled` - `0` or `1`, disables or enables the logger. Default is `1`
* `log.level` - minimum verbosity level of the logger. Default is `"debug"` in debug builds and `"info"` in release builds. Supported options are:
  * `"debug"` - debug mode, prints all messages
  * `"info"` - prints informational messages, warnings and errors
  * `"warning"` - prints warnings and errors
  * `"error"` - prints only errors
* `log.toStdout` - `0` or `1`, disables or enables printing log messages to the standard output. Default is `1`
* `log.timestampTags` - `0` or `1`, disables or enables timestamps in log messages. Default is `0`
* `log.levelTags` - `0` or `1`, disables or enables level tags in log messages. Default is `1`
* `log.file` - enables logging to file, specifying the filename. File output for the logger is disabled by default

VFS settings:

* `vfs.appDataFolder` - game data folder name in `APPDATA` directory (`HOME` under Linux). These value override default one hardcoded in the application
* `vfs.appDataFolder.windows` - overrides `vfs.appDataFolder` under Windows
* `vfs.appDataFolder.linux` - overrides `vfs.appDataFolder` under Linux
* `vfs.mount` - additional paths to mount in the VFS, separated by semicolon (`"my/path;my/another/path"`)
* `vfs.mount.windows` - overrides `vfs.mount` under Windows
* `vfs.mount.linux` - overrides `vfs.mount` under Linux

Window settings:

* `window.display` - the index of the display on which the game window should be displayed (in multi-display configurations). Default is `0`
* `window.width`, `window.height` - size of the game window. These values override default ones hardcoded in the application
* `window.x`, `window.y` - window position (in non-maximized windowed mode). If not specified, the window is centered on the screen
* `window.resizable` - `0` or `1`, allow the user to resize the window or not (in windowed mode). Default is `1`
* `window.maximized` - `0` or `1`, maximize the window initially. If enabled, `window.width` and `window.height` are ignored. Default is `0`
* `window.minimized` - `0` or `1`, minimize the window initially. Default is `0`
* `window.borderless` - `0` or `1`, enables or disables window decoration. Default is `0`
* `window.hiDPI` - `0` or `1`, hints that the application is hiDPI-aware. If enabled, the actual drawable area of the window will be larger than the window itself (by multiplier available as `Application.pixelRatio`) on appropriate displays. Default is `0`
* `window.title` - window title text. This value overrides default one hardcoded in the application
* `window.HDROutput` - `0` or `1`, enables or disables HDR display support

Application settings:

* `fullscreen` - `0` or `1`, run in windowed or fullscreen mode. This value overrides default one hardcoded in the application
* `fullscreenWindowed` - `0` or `1`, enables "windowed fullscreen" mode. The application runs in a borderless screen-sized window, which allows for easy switching to other applications. Default is `0`
* `vsync` - `0` for immediate buffer swap; `1` for synchronization with the vertical retrace; `2` for Mailbox mode. Default is `2`
* `updatesPerSecond` - number of logic updates per second (UPS). This can be set to `auto` or `0` to synchronize updates with the display refresh rate. Default is `60`
* `maxTimersCount` - maximum number of simultaneous timers. Default is `1024`. `0` is treated as a default number
* `hideConsole` - `0` or `1`, show or hide the console window. It is convenient to leave it when debugging the game and hide it for end users. Default is `0`
* `supersampling` - 
* `stereoRendering` - `0` or `1`, reserved option

Locale settings:

* `localesPath` - path to the folder containing translation files. Default is `"locale"`
* `locale` - locale that should be loaded. This option overrides automatically selected locale based on system language and region. For example, `locale: "en_US";` means that application will try load `locale/en_US.lang` file and will ignore system language

GPU settings:

* `gpu.shaderCache.enabled` - `0` or `1`, cache compiled shader binaries (SPIR-V code) to files for reuse instead of compiling shaders on each run. Default is `1`
* `gpu.shaderCache.path` - path to a folder for storing cached shader binaries. Default is `"data/__internal/shader_cache"`
* `gpu.shaderCache.path.windows` - overrides `gl.shaderCache.path` under Windows
* `gpu.shaderCache.path.linux` - overrides `gl.shaderCache.linux` under Windows
* `gpu.shaderCache.enableLogging` - `0` or `1`, switch logging of shader cache operations
* `gpu.textureCache.enableLogging` - `0` or `1`, switch logging of texture cache operations
* `gpu.debugOutput` - `0` or `1`, force disable or enable GPU debug output. Default is `1` in debug builds, `0` in release builds. This option is ignored if `logLevel` is higher than `"debug"`
* `gpu.anisotropicFiltering` - `0` or `1`, disable or enable anisotropic filtering by default for all textures. Default is `0`
* `gpu.defaultTextureAnisotropy` - default anisotropic filtering level for all textures loaded using the asset manager. The value is clamped between `1.0` and the maximum anisotropy supported by hardware (`"auto"`). If anisotropic filtering is not supported, this is set to `1.0`. Default is `1.0`

SDL3 settings:

* `SDL3.path` - path to SDL3 shared library. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified (default case), `"SDL3.dll"` is used under Windows, and `"libSDL3.so.0"` is used under Linux
* `SDL3.path.windows` - path to SDL3 shared library under Windows, overrides `SDL3.path`. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified, `"SDL3.dll"` is used
* `SDL3.path.linux` - path to SDL3 shared library under Linux, overrides `SDL3.path`. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified, `"libSDL3.so.0"` is used
* `SDL3Image.path` - path to SDL3_Image shared library. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified (default case), `"SDL3_Image.dll"` is used under Windows, and `"libSDL3_image.so"` is used under Linux
* `SDL3Image.path.windows` - path to SDL3_Image shared library under Windows, overrides `SDL3Image.path`. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified, `"SDL3_Image.dll"` is used
* `SDL3Image.path.linux` - path to SDL3_Image shared library under Linux, overrides `SDL3Image.path`. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified, `"libSDL3_image.so"` is used

FreeType settings:

* `FreeType.path` - path to FreeType shared library. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified (default case), `"freetype-6.dll"` is used under Windows, and under Linux the path is automatically determined by the library loader
* `FreeType.path.windows` - path to FreeType shared library under Windows, overrides `FreeType.path`. If empty string or `"auto"` specified, `"freetype-6.dll"` is used
* `FreeType.path.linux` - path to FreeType shared library under Linux, overrides `FreeType.path`. If empty string or `"auto"` specified, the path is automatically determined by the library loader

KTX settings:

* `KTX.path` - path to libktx shared library. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified (default case), `"ktx.dll"` is used under Windows, and `"libktx.so"` is used under Linux
* `KTX.path.windows` - path to libktx shared library under Windows, overrides `KTX.path`. If empty string or `"auto"` specified, `"ktx.dll"` is used
* `KTX.path.linux` - path to libktx shared library under Linux, overrides `KTX.path`. If empty string or `"auto"` specified, `"libktx.dll"` is used

Assimp settings:

* `Assimp.path` - path to Assimp shared library. If empty string specified, the path is automatically determined by the library loader. If `"auto"` specified (default case), `"Assimp.dll"` is used under Windows, and `"libassimp.so"` is used under Linux
* `Assimp.path.windows` - path to Assimp shared library under Windows, overrides `Assimp.path`. If empty string or `"auto"` specified, `"Assimp.dll"` is used
* `Assimp.path.linux` - path to Assimp shared library under Linux, overrides `Assimp.path`. If empty string or `"auto"` specified, `"libassimp.dll"` is used

Event manager settings:

* `events.keyRepeat` - enable repeated triggering of "key down" events when user presses and holds a key. This is generally only useful for text input in GUI applications. Default is `0`
* `events.gamepadAxisThreshold` - defines maximum value of controller axis for normalization. Default is `32639`
* `events.graphicsTablet.enabled` - `0` or `1`, disable or enable graphics tablet events (if device is available). Default is `1`.

### render.conf

TODO
