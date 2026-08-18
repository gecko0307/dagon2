# dagon2:audio

Audio extension based on [SoLoud fork](https://github.com/gecko0307/soloud).

Fork adds the following features:
- SDL3 backend based on the reworked [PR #402](https://github.com/jarikomppa/soloud/pull/402)
- DirectSound backend
- New build process using CMake 3
- Numerous minor fixes across the codebase.

## Basic Usage

Start with creating an `AudioManager` in your game class:

```d
import dagon.ext.audio;

class MyGame: Game
{
    AudioManager audioManager;
    
    this(uint windowWidth, uint windowHeight, bool fullscreen, string title, string[] args)
    {
        super(windowWidth, windowHeight, fullscreen, title, args);
        audioManager = New!AudioManager(this);
    }
}
```

In your world create a sound and play it:

```d
class MyWorld: World
{
    MyGame game;
    AudioManager audio;
    Wav sound;
    
    this(MyGame game)
    {
        super(game);
        this.game = game;
        this.audio = game.audioManager;
        
        sound = audio.loadSound("assets/sounds/sound.wav");
        audio.play(sound);
    }
    
    // Post-update is used to ensure all world transformations are valid and ready to feed into the manager
    override void onPostUpdate(Time t)
    {
        audio.update(t);
    }
}
```

For streamed sounds like background music or ambient noise use `loadMusic`:

```d
sound = audio.loadMusic("assets/music/track.mp3");
```

`loadMusic` loads the entire file at once, which increases memory usage, but provides best performance, while `streamMusic` will buffer and decode portions or the file as the track is playing, thus reducing memory usage, but adding an I/O overhead.

## 3D Sound

To play a spatial sound (which has a position in 3D space) there are two possible ways. A simple method is to use `playAtPosition`:

```d
int voice = audio.playAtPosition(sound, Vector3f(1.0f, 2.0f, 3.0f));
```

Sound played this way can't change its position, so it can be more convenient to attach a sound source to an entity using a `SoundComponent`. The sound will automatically follow the entity, which is useful to model a talking person or a car.

```d
SoundComponent sc = audio.addSoundTo(myEntity);
sc.play(sound);
```

For 3D sound to work, you need a listener, an entity that is used for spatial perception. This is usually the camera used for rendering:

```d
audio.listener = camera;
```
