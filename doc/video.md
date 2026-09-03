# Video

Dagon supports video playback via dagon:video extension which is based on libVLC, a free video framework which is part of the [VLC Media Player](https://github.com/videolan/vlc). It supports all popular video formats. The video is decoded to GPU texture and can be used in the engine just as any normal texture.

## Libraries and Plugins

The extension depends on `libvlccore.dll` and `libvlc.dll` (`libvlccore.so.9`, `libvlc.so` and `libidn.so.11` under Linux). Also a number of plugins are necessary for libVLC to work properly. They are stored in `plugins` folder under Windows and `plugins_linux` folder under Linux.

## Usage

TODO
