# Input Manager

Any game has some way of user interaction - via mouse, keyboard, or a gamepad. In Dagon, the simplest way to add user input is to listen to keyboard, mouse and gamepad events in your world (or in any other `EventListener` implementation) and take action when particular event occurs. But this approach is suitable only for simple demos. In a real game you'll want to give players a possibility to customize game controls, so you are not going to hardcode any keys or gamepad buttons in the game code. Dagon provides an input manager that abstractizes the way how user interacts with the application. It allows to use abstract logic commands like "go forward", "jump", "fire", etc. Keyboard/gamepad mappings for these commands are be defined in a user-editable configuration file `input.conf`. The input manager is available in `EventManager` class as `inputManager` property. Any `EventListener` has a shortcut to it, so you can use it directly from your world.

A logic command in this system is called "binding". Bindings are defined in `input.conf` file in your game's directory. The following is a content of a simple `input.conf` that you can copy to your project:

```
forward: "kb_w, kb_up, gb_b";
back: "kb_s, kb_down, gb_a";
left: "kb_a, kb_left";
right: "kb_d, kb_right";
jump: "kb_space";
interact: "kb_e";
```

Binding definition format consists of device type and name (or number) coresponding to button or axis of this device.

- `kb` - keyboard (`kb_up`, `kb_w`, etc.)
- `ma` - mouse axis (`ma_x`, `ma_y`)
- `mb` - mouse button (`mb_left`, `mb_right`, etc.)
- `ga` - gamepad axis (`ga_leftx`, `ga_lefttrigger`, etc.)
- `gb` - gamepad button (`gb_a`, `gb_x`, etc.)
- `va` - virtual axis, has special syntax, for example: `va(kb_up, kb_down)`

`ga` and `gb` bindings accept optional gamepad index, for example: `gb[0]_x` or `ga[1]_lefty`. Up to 4 gamepads are supported.

To use input manager, you don't need to subscribe to events, all is done with the `getButton` method:

```d
override void onUpdate(Time t)
{
    if (inputManager.getButton("forward"))
        character.move(-camera.directionWorld, speed);
    if (inputManager.getButton("jump"))
        character.jump();
}
```

`getButton` is a continuous check, there are also `getButtonDown` and `getButtonUp` to check if a binding is triggered or released, respectively.

There's also `getAxis` method that returns a value in -1..1 range, which is useful for analog controls, such as steering in racing games. For example, you can assign gamepad axes and several virtual axes to `horizontal` and `vertical` bindings in your configuration:

```
horizontal: "ga_leftx, va(kb_right, kb_left), va(gb_dpright, gb_dpleft)";
vertical: "ga_lefty, va(kb_down, kb_up), va(gb_dpdown, gb_dpup)";
```

```d
override void onUpdate(Time t)
{
    spaceship.yaw(inputManager.getAxis("horizontal"));
    spaceship.pitch(inputManager.getAxis("vertical"));
}
```
