# AutoRunSteer

Steer your autorun with the camera stick in **World of Warcraft: Forever**'s gamepad mode.

Out of the box, the gamepad camera only turns your character while you're moving the left stick, so
during autorun the right stick just swings the camera around and you can't change direction without
cancelling the run. AutoRunSteer adds a simple gesture for it:

- **Tap** the autorun button: plain autorun, the camera stick only moves the camera.
- **Tap and keep holding** the autorun button for about half a second: autorun starts and the camera
  stick now steers it. You get a short controller rumble and an "Autorun steering on" message.
- Steering ends by itself when the autorun does (you stop, toggle autorun off, or press forward/back).

It never changes your saved settings: while steering, it temporarily switches the game's
"Turn Player with Camera" option to "always" and puts it back the moment the autorun ends.

## Install

- **CurseForge app:** coming soon.
- **Manually:** download `AutoRunSteer-<version>-forever.zip` from the
  [latest release](https://github.com/sememtac/AutoRunSteer/releases/latest) and extract it into
  `World of Warcraft\_forever_\Interface\AddOns\`, so you end up with
  `...\AddOns\AutoRunSteer\AutoRunSteer.toc`. Restart the game (a `/reload` doesn't pick up new addons).

## Commands

| Command | What it does |
|---|---|
| `/autorunsteer` | Turn the addon on/off |
| `/autorunsteer on` / `off` | Turn it on or off |
| `/autorunsteer hold 0.8` | How long to hold the button before steering kicks in (0.2 – 2 seconds, default 0.5) |
| `/autorunsteer status` | Show the current state and which button it sees bound to autorun |
| `/autorunsteer debug` | Print what happens on each autorun press (for troubleshooting) |

## Works best with

Options → Gameplay → Gamepad → Camera:

- **Movement Face Angle** and **Movement Face Angle Combat** at 180, so forward follows the camera and
  left/right strafe.
- **Turn Player with Camera** set to "Player turns with camera when moving", so the camera only orbits
  while you stand still.

## Troubleshooting

If holding the button doesn't turn steering on, run `/autorunsteer debug`, do one long hold, and open
an issue with the chat lines it prints.

## License

[MIT](LICENSE)
