# Changelog

All notable changes to Lighthouse are recorded here, one entry per stage.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [Stage 6] - 2026-11-27

### Added
- `data/item_data.gd`: 13 items (weapons, lighthouse defences, vehicles) with a minimum rank and a fixed price each.
- `scenes/ui/armoury.tscn`: lists every item by type, showing owned, unlocked or locked (with the rank needed). Opened from the hub.
- `GameManager`: `can_use`, `usable_turrets`, `max_turrets` (1 + rank index), `rank_progress`.
- HUD shows points to the next rank and a PROMOTED or DEMOTED banner when the rank changes.

### Changed
- Turrets in the base defence and the carry-on calculation are capped by rank slots.
- Hub label shows turret slots and says Stage 6.

## [Stage 5] - 2026-11-27

### Added
- `data/mission_data.gd`: three starter missions (Perimeter sweep, Nest raid, Deep strike) with kills, risk, minimum rank, rewards, and base-attack chance, timing and strength.
- `scenes/missions/mission_select.tscn`: mission list showing rewards and risk, locked missions with the rank they need, base and core status, and a repair button (1 qubit per 5 base health, 1 qubit per 2 core integrity).
- `scenes/missions/mission_level.tscn`: a field mission. Scouts spawn around you until you have eliminated the required number. Complete pays qubits and points. Dying fails the mission.
- The base-attack choice. At a random time (chance depends on the mission) the game pauses with the attack strength and what each option costs.
  - Defend the base: mission abandoned, reward lost, you fight a single wave of attackers at the lighthouse. Repelling it earns 25 points plus 2 per attacker.
  - Carry on: each turret stops 4 attackers, every other attacker does 60 damage to the base (then core) and costs 12 rank points, plus a flat 10. If the core falls the lighthouse is rebuilt and the mission fails.
- `GameManager`: `preview_unattended_attack`, `resolve_unattended_attack`, `repair_cost`, `repair_all`, `pending_attack`, and the tuning constants for all of the above.
- `scripts/level_builder.gd`: shared environment, ground and box helpers.
- Wave manager `single_wave` and `wave_size_override` options.
- Progress is saved when a mission ends or an attack is repelled.
- "Missions" button on the main test screen.

### Changed
- The HUD centre panel is now generic: `show_panel(text, labels)` and a `panel_choice(index)` signal replace the old restart signal.
- The defence level has an attack mode (one wave, base health carried over) alongside the endless mode.

### Notes
- Rank points and demotion now flow from missions. Stage 6 adds the rank unlocks.
- The test arena and defence level still build their own floors. They can move to the level builder later.
- Not yet run in Godot. Report any errors from the editor and they will be fixed in the next update.

## [Stage 4] - 2026-11-26

### Added
- `scenes/base/base_defence.tscn` and `base_defence.gd`: the defence level. Big flat map with invisible boundary walls, the lighthouse in the middle, your turret(s), and the player starting in front of the tower. "Defend the lighthouse" button on the main test screen.
- `scenes/base/lighthouse_base.gd`: the lighthouse. Striped tower, glowing lamp room with a rotating beam, and a window showing the power core that pulses and shifts from amber to red as core integrity drops. Damage hits base health first, then the core. Enemy bites do 40% damage to the lighthouse.
- `scenes/base/turret.gd`: automatic turret. Range 28, 18 damage every 0.45s. One is placed per turret in the inventory, up to 4 spots.
- `scenes/base/wave_manager.gd`: endless waves of scouts. Wave n has 4 + 2 x (n - 1) scouts, at most 8 alive, 1.2s between spawns, 8s break between waves, 4s before the first wave. Scouts spawn on a ring around the map.
- `scenes/ui/game_hud.gd`: shared in-game HUD with touch controls, rank and qubits, status line, heat bar, damage flash, wave banners, Back button and a game-over panel. Works while paused.
- `scripts/fx.gd`: shared tracer and glow-material helpers.
- `GameManager.reset_base()` and `repair_core()`.
- `EventBus.wave_started` and `wave_cleared`.
- Game over when the core is destroyed, with Try again and Back to menu. 150 base health restored when a wave is cleared. Dying as the player respawns you at the start.

### Changed
- Scouts now go for the lighthouse and switch to the player when the player is within 12 metres. In the test arena (no lighthouse) they still hunt the player.
- Scouts slide along walls and cover when blocked, so they do not get stuck pushing into them.

### Notes
- No navigation mesh yet. Scouts steer in a straight line and slide off obstacles. A real navigation mesh can come later if needed.
- Wave rewards, points and mission links come in Stages 5 to 7.
- Not yet run in Godot. Report any errors from the editor and they will be fixed in the next update.

## [Stage 3] - 2026-11-26

### Added
- `scenes/weapons/energy_rifle.gd`: starter energy rifle. Hitscan, hold to fire, 25 damage, 0.15s between shots. Builds heat (8 per shot), overheats at 100 and locks until cooled to 40. Visible rifle model, muzzle flash, bolt tracer and impact spark.
- `scenes/enemies/scout.gd`: scout enemy. 40 health, speed 7, weaving chase toward the player, bites for 10 damage every 0.8s. Bio-mechanical look from simple shapes (flesh body, metal plate, glowing eye). Flashes when hit and shrinks away on death.
- Player health (100), `take_damage`, `reset`, and `died` and `health_changed` signals.
- Arena: scouts spawn every 2.5s on the arena edge (max 6 alive), kill counter, health readout, heat bar, red flash when hurt, respawn on death.
- `EventBus.enemy_killed(enemy_type)`.

### Changed
- The placeholder hitscan shot moved out of the player and into the rifle.

### Notes
- Scouts steer in a straight line toward the player. Navigation around obstacles comes with the base in Stage 4.
- Kills do not give points or qubits yet. That is wired up with missions and rank.
- Not yet run in Godot. Report any errors from the editor and they will be fixed in the next update.

## [Stage 2] - 2026-11-26

### Added
- `scenes/player/player.tscn` and `player.gd`: first-person player with gravity, WASD and mouse look on desktop, and a placeholder hitscan shot (25 damage, 0.15s between shots).
- `scenes/ui/touch_controls.tscn` and `touch_controls.gd`: floating move joystick on the left, drag-to-look on the right, fire button bottom right, crosshair. Shown automatically on touchscreens.
- `scenes/levels/test_arena.tscn` and `test_arena.gd`: floor, walls, glowing cover, five practice targets, HUD with rank and qubits, and a Back button.
- `scenes/levels/target.gd`: shootable target that flashes when hit and respawns after 2 seconds.
- "Start test arena" button on the main test screen.
- README: Controls table.

### Notes
- The shot is a placeholder. The real energy rifle comes in Stage 3.
- Input actions (move, fire) are registered in code, so `project.godot` is unchanged.
- Not yet run in Godot. Report any errors from the editor and they will be fixed in the next update.

## [Stage 1] - 2026-11-26

### Added
- `project.godot`: Godot 4.3, Mobile renderer, landscape orientation, 1280x720 viewport, logo as project icon.
- `autoload/event_bus.gd`: global signals for economy, rank, base, missions, colonies and story.
- `autoload/game_manager.gd`: qubits (start 3,500), points and the seven ranks with demotion, base health and core integrity, mission state, inventory with the starting loadout (jet, turret, energy rifle, machete), fallen colonies, and JSON save and load.
- `scenes/levels/main.tscn` and `main.gd`: test screen showing the game state, with buttons to try points, demotion, spending, a base attack, save and new game.
- README: Getting started section.

### Notes
- Rank point thresholds are placeholders (0, 100, 300, 600, 1000, 1600, 2500), to be tuned in Stage 6.
- Not yet run in Godot. Report any errors from the editor and they will be fixed in the next update.

## [Stage 0] - 2026-11-26

### Added
- Repository skeleton: `autoload/`, `scenes/` (player, weapons, enemies, jet, base, colonies, missions, levels, ui), `scripts/`, `assets/`, `audio/`, `data/`.
- `README.md` with the logo at the top.
- Logo: a shield made of honeycomb cells with a lighthouse inside, as `assets/logo/logo.png` and editable `assets/logo/logo.svg`.
- Godot 4 `.gitignore`.
- `CHANGELOG.md` and `PROGRESS.md`.

### Design
- Currency named qubit. The Market sells everything. Raw goods have changing prices, everything else is fixed. Fallen colonies pay less and sell cheaper.
- Bought items need the matching rank.
- Starting loadout: jet, turret, 3,500 qubits, gun, sword or machete.
- First-launch intro story added to the plan.
