<p align="center">
  <img src="assets/logo/logo.png" alt="Lighthouse logo" width="200">
</p>

<h1 align="center">Lighthouse</h1>

<p align="center">
  A futuristic first-person shooter with base defence, built in Godot for Android.
</p>

---

## About

You are an operative of a secret agency whose home base is a lighthouse. Inside it sits the power core that drives the planet. Bio-mechanical aliens from beyond Earth are invading, because they feed on that core.

Missions take you out into the world, but the base can be attacked at any moment. Defend it or finish the mission: you can only pick one, and every choice has consequences for your rank. You can also launch a fighter jet from the base hangar to fight in the sky.

## Status

Planning phase. The design is settled and no game code exists yet.

## Tech

- Engine: Godot 4 (Mobile renderer)
- Language: GDScript
- First platform: Android

## Getting started

1. Install Godot 4.3 or newer (standard version, not .NET).
2. Open Godot, choose Import, and select `project.godot`.
3. Press F5 to run. The test screen shows rank, qubits and base health, with buttons to try the game state, and a **Start test arena** button.

### Controls

| | Desktop | Phone |
| --- | --- | --- |
| Move | WASD | Left thumb joystick (appears where you touch) |
| Look | Mouse (click to capture, Esc to release) | Drag on the right side |
| Fire (hold) | Left click or Space | Fire button, bottom right |

### What to try in the arena

Scouts spawn around the edge and rush you. Each takes two rifle hits. The rifle builds heat as you fire (bar at the top), locks if it overheats, and recovers once cooled. Scouts bite for 10 damage. At 0 health you respawn at the start.

### Defend the lighthouse

Press **Defend the lighthouse** on the test screen. Waves of scouts attack the tower. Damage hits the base health first, then the power core. If the core reaches 0 it is game over. A turret from your starting loadout helps. Between waves the base is repaired a little.

## Project structure

```
autoload/    global singletons (game manager, event bus)
scenes/      player, weapons, enemies, jet, base, colonies, missions, levels, ui
scripts/     shared code not tied to one scene
assets/      models, textures, fonts, icons, logo
audio/       music, sfx, radio
data/        ranks, mission and enemy stats
```

## Logo

The logo lives at `assets/logo/logo.png`. Replace that file with the final version and the image at the top of this README updates automatically.

## License

To be decided (personal or open source).
