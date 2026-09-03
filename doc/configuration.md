# Configuration

This guide covers Dagon's built-in runtime configuration system. The engine uses *.conf files to store user-controllable settings.

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
* `log.level` - string, minimum verbosity level of the logger. Default is `"debug"` in debug builds and `"info"` in release builds. Supported options are:
  * `"debug"` - debug mode, prints all messages
  * `"info"` - prints informational messages, warnings and errors
  * `"warning"` - prints warnings and errors
  * `"error"` - prints only errors
* `log.toStdout` - `0` or `1`, disables or enables printing log messages to the standard output (console). Default is `1`
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
* `vsync` - `0` for immediate buffer swap; `1` for synchronization with the vertical retrace; `2` for Mailbox mode. Default is `2`, but it may be not supported on some systems, in which cases it falls back to 
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

Recognized by the `Game` class, applied to the `Game.renderer`.

* `profile` - renderer quality profile. Supported values are `0` (low quality), `1` (high quality), `2` (ultra quality). Default is `2`. All explicitly defined options below override the profile

* `decals.enabled` - `0` or `1`, disable or enable decals. Default is `1`

* `selfIllumination.enabled` - `0` or `1`, disable or enable self-illumination (material emission). Default is `1`

* `sunLight.enabled` - `0` or `1`, disable or enable sun light. Default is `1`

* `lightVolumes.enabled` - `0` or `1`, disable or enable light volumes (positional lights). Default is `1`

* `fog.enabled` - `0` or `1`, disable or enable fog. Default is `1`

* `ssao.enabled` - `0` or `1`, disable or enable screen-space ambient occlusion. Default is `1` in high/ultra quality profile, and `0` in low quality profile
* `ssao.samplesMin` - minimum number of SSAO integration samples per pixel. Default is `20` in high/ultra quality profile, and `10` in low quality profile
* `ssao.samplesMax` - maximum number of SSAO integration samples per pixel. Default is `40` in high/ultra quality profile, and `10` in low quality profile
* `ssao.radius` - maximum radius of occlusion detection for SSAO
* `ssao.power` - SSAO power. The greater is power, the more pronounced is the occlusion effect
* `ssao.temporalAccumulation` -
* `ssao.denoise` -
* `ssao.halfResolution` - 

* `sslr.enabled` - `0` or `1`, disable or enable screen-space reflections. Default is `1` in high/ultra quality profile, and `0` in low quality profile
* `sslr.samples` -
* `sslr.refineSamples` -
* `sslr.maxRayDistance` -
* `sslr.hitThickness` -
* `sslr.velocitySensitivity` -
* `sslr.historyWeight` -
* `sslr.motionWeight` -
* `sslr.blur` -
* `sslr.blurRadius` -
* `sslr.halfResolution` -

* `motionBlur.enabled` - `0` or `1`, disable or enable motion blur filter. Default is `1` in high/ultra quality profile, and `0` in low quality profile
* `motionBlur.samples` - 
* `motionBlur.framerate` - 
* `motionBlur.randomness` - 
* `motionBlur.minDistance` - 
* `motionBlur.maxDistance` - 
* `motionBlur.radialBlurAmount` - 

* `tonemapping.enabled` - `0` or `1`, disable or enable AgX tone mapping filter. Default is `1`
* `tonemapping.look` -
* `tonemapping.look.offset` -
* `tonemapping.look.slope` -
* `tonemapping.look.power` -
* `tonemapping.look.saturation` -

* `lensDistortion.enabled` - `0` or `1`, disable or enable lens distortion filter. Default is `1` in high/ultra quality profile, and `0` in low quality profile
* `lensDistortion.scale` - 
* `lensDistortion.dispersion` - 
* `lensDistortion.useRadialDistortion` - 
* `lensDistortion.k1` - 
* `lensDistortion.k2` - 

* `antialiasing` - anti-aliasing algorithm. Supported values are `"None"`, `"FXAA"`, `"SMAA"`. Default is `"SMAA"` in high/ultra quality profile, and `"FXAA"` in low quality profile

* `sharpening.enabled` - `0` or `1`, disable or enable sharpening filter. Default is `1` in high/ultra quality profile, and `0` in low quality profile
* `sharpening.strength` -

### input.conf

`input.conf` contains input bindings recognozed by the `InputManager` class.

Binding definition format consists of device type and name (or number) coresponding to button or axis of this device.

- `kb` - keyboard (`kb_up`, `kb_w`, etc.)
- `ma` - mouse axis (`ma_x`, `ma_y`)
- `mb` - mouse button (`mb_left`, `mb_right`, etc.)
- `ga` - gamepad axis (`ga_leftx`, `ga_lefttrigger`, etc.)
- `gb` - gamepad button (`gb_a`, `gb_x`, etc.)
- `va` - virtual axis, has special syntax, for example: `va(kb_up, kb_down)`

`ga` and `gb` bindings accept optional gamepad index, for example: `gb[0]_x` or `ga[1]_lefty`. Up to 4 gamepads are supported. Default gamepad index is 0.

Example:

```
forward: "kb_w, kb_up, gb[0]_b";
back: "kb_s, kb_down, gb[0]_a";
left: "kb_a, kb_left";
right: "kb_d, kb_right";
jump: "kb_space";
interact: "kb_e";

Supported key names:
- `kb_a` .. `kb_z`, `kb_0` .. `kb_9`
- `kb_-`, `kb_=`, `kb_[`, `kb_]`, `kb_\`, `kb_#`, `kb_;`, `kb_'`, `kb_,`, `kb_.`, `kb_/`
- `kb_return`, `kb_escape`, `kb_backspace`, `kb_delete`, `kb_tab`, `kb_space`, `kb_capsLock`
- `kb_f1` .. `kb_f24`
- `kb_printscreen`, `kb_scrolllock`, `kb_numlock`, `kb_pause`, `kb_insert`, `kb_home`, `kb_pageup`, `kb_pagedown`, `kb_end`
- `kb_left`, `kb_right`, `kb_up`, `kb_down`
- `kb_left_ctrl`, `kb_left_shift`, `kb_left_alt`, `kb_left_gui`
- `kb_right_ctrl`, `kb_right_shift`, `kb_right_alt`, `kb_right_gui`
- `kb_keypad_0` .. `kb_keypad_9`
- `kb_keypad_/`, `kb_keypad_*`, `kb_keypad_-`, `kb_keypad_+`, `kb_keypad_=`, `kb_keypad_enter`, `kb_keypad_.`, `kb_keypad_,`, `kb_keypad_00`, `kb_keypad_000`
- `kb_keypad_(`, `kb_keypad_)`, `kb_keypad_{`, `kb_keypad_}`, `kb_keypad_tab`, `kb_keypad_backspace`
- `kb_keypad_a`, `kb_keypad_b`, `kb_keypad_c`, `kb_keypad_d`, `kb_keypad_e`, `kb_keypad_f`
- `kb_keypad_xor`, `kb_keypad_^`, `kb_keypad_%`, `kb_keypad_<`, `kb_keypad_>`, `kb_keypad_&`, `kb_keypad_&&`, `kb_keypad_|`, `kb_keypad_||`, `kb_keypad_:`, `kb_keypad_#`, `kb_keypad_space`, `kb_keypad_@`, `kb_keypad_!`
- `kb_keypad_memstore`, `kb_keypad_memrecall`, `kb_keypad_memclear`, `kb_keypad_memadd`, `kb_keypad_memsubtract`, `kb_keypad_memmultiply`, `kb_keypad_memdivide`
- `kb_keypad_+/-`, `kb_keypad_clear`, `kb_keypad_clearentry`, `kb_keypad_binary`, `kb_keypad_octal`, `kb_keypad_decimal`, `kb_keypad_hexadecimal`
- `kb_mediaplay`, `kb_mediapause`, `kb_mediarecord`, `kb_mediafastforward`, `kb_mediarewind`, `kb_mediatracknext`, `kb_mediatrackprevious`, `kb_mediastop`, `kb_mediaplaypause`, `kb_mediaselect`
- `kb_nonusbackslash`, `kb_application`, `kb_power`
- `kb_execute`, `kb_help`, `kb_menu`, `kb_select`, `kb_stop`, `kb_again`, `kb_undo`, `kb_cut`, `kb_copy`, `kb_paste`, `kb_find`, `kb_mute`, `kb_volumeup`, `kb_volumedown`
- `kb_international_1` .. `kb_international_9`
- `kb_language_1` ..`kb_language_9`
- `kb_alterase`, `kb_sysreq`, `kb_cancel`, `kb_clear`, `kb_prior`, `kb_separator`, `kb_out`, `kb_oper`, `kb_clear_/_again`, `kb_crsel`, `kb_exsel`
- `kb_thousandsseparator`, `kb_decimalseparator`, `kb_currencyunit`, `kb_currencysubunit`
- `kb_modeswitch`, `kb_sleep`, `kb_wake`, `kb_channelup`, `kb_channeldown`
- `kb_eject`, 
- `kb_ac_new`, `kb_ac_open`, `kb_ac_close`, `kb_ac_exit`, `kb_ac_save`, `kb_ac_print`, `kb_ac_properties`, `kb_ac_search`, `kb_ac_home`, `kb_ac_back`, `kb_ac_forward`, `kb_ac_stop`, `kb_ac_refresh`, `kb_ac_bookmarks`
- `kb_softleft`, `kb_softright`
- `kb_call`, `kb_endcall`

Supported mouse button and axis names:
- `mb_left`, `mb_middle`, `mb_right`, `mb_x1`, `mb_x2`
- `ma_x`, `ma_y`

Supported gamepad button and axis names:
- `gb_dpup`, `gb_dpdown`, `gb_dpleft`, `gb_dpright`
- `gb_a`, `gb_b`, `gb_x`, `gb_y`
- `gb_back`, `gb_guide`, `gb_start`
- `gb_leftstick`, `gb_rightstick`
- `gb_leftshoulder`, `gb_rightshoulder`
- `gb_misc` (Xbox Series X share button, PS5 microphone button, Nintendo Switch Pro capture button, Amazon Luna microphone button)
- `gb_paddle1`, `gb_paddle2`, `gb_paddle3`, `gb_paddle4` (Xbox Elite paddles in order, facing the back: upper left, upper right, lower left, lower right)
- `gb_touchpad` (PS4/PS5 touchpad button)
- `ga_leftx`, `ga_lefty`
- `ga_rightx`, `ga_righty`
- `ga_triggerleft`, `ga_triggerright`

### audio.conf

Recognized by the `AudioManager` class of the dagon:audio extension.

* `enabled` - `0` or `1`
* `backend` - string, backend API for audio output. This option is platform-specific: not all backends work on all platforms. It is recommended to change backend only if automatically selected one is not working. Supported options are:
  * `"auto"` - default value, backend is automatically selected
  * `"SDL1"` - cross-platform
  * `"SDL2"` - cross-platform
  * `"SDL3"` - cross-platform (normally automatically selected option because SDL3 is Dagon's core dependency)
  * `"PortAudio"` - cross-platform
  * `"WinMM"` - Windows-only
  * `"XAudio2"` - Windows-only
  * `"WASAPI"` - Windows-only
  * `"DirectSound"` - Windows-only
  * `"ALSA"` - Linux-only
  * `"JACK"` - Linux-only
  * `"OSS"` - Linux-only
  * `"OpenAL"` - cross-platform
  * `"MiniAudio"` - cross-platform
  * `"NoSound"` - disables sound output
* `channels` - number of audio output channels. To use 5.1, specify `6`. To use 7.1, specify `8`. When using multichannel output, dagon:audio will map 3D sound to the specified number of channels for surround effect. Default is `2` (stereo)
* `sampleRate` - output sample rate in Hz. Automatically chosen by default (`"auto"`)
* `bufferSize` - output buffer size in bytes. Automatically chosen by default (`"auto"`)
* `master.volume` - a number in 0.0..1.0 range. Global audio output volume. Default is `1.0`
* `master.fadeInDuration` - master volume fade-in in seconds. This is used to smoothly increase volume after the initialization, so that there will be no unpleasant "click" noise. Default is `0.25`
* `music.enabled` - `0` or `1`. Disables or enables playing of sounds created as `SoundClass.Music`. Default is `1`
* `music.volume` - a number in 0.0..1.0 range. Background music volume (for sounds created as `SoundClass.Music`). Default is `0.5`
* `sfx.enabled` - `0` or `1`. Disables or enables playing of sounds created as `SoundClass.SFX`. Default is `1`
* `sfx.volume` - a number in 0.0..1.0 range. Sound effects volume (for sounds created as `SoundClass.SFX`). Default is `0.5`
* `multimediaKeysEnabled` - `0` or `1`. Use multimedia keys found on some keyboards to control the active playlist. Note that audio players often hijack multimedia keypresses, in which cases they are not detected by Dagon. Default is `1`
