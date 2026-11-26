# Progress

Lighthouse is built in stages. After each stage this file and `CHANGELOG.md` are updated and a full project zip is delivered.

**Current stage:** Stage 0 complete. Next: Stage 1.

| Stage | Goal | Status |
| --- | --- | --- |
| 0 | Repo skeleton, README with logo, logo, changelog, progress file | Done |
| 1 | Godot project file, Mobile renderer, `game_manager` and `event_bus` autoloads | Next |
| 2 | Test arena: first-person player, touch joystick and aim area, fire button | Planned |
| 3 | Energy rifle and the first enemy (scout) with basic AI | Planned |
| 4 | Lighthouse base scene, power core and wave defence | Planned |
| 5 | Missions and the base-attack choice (defend or continue) | Planned |
| 6 | Rank, points, demotion and rank unlocks | Planned |
| 7 | Qubits, automated colony trade and the Market screen | Planned |
| 8 | Hangar and fighter jet with touch flight controls | Planned |
| 9 | Ten colonies, fall and retake, radio story, first-launch intro story | Planned |
| 10 | More enemies and weapons, base defences, polish, Android export | Planned |

## Decisions so far

- Engine: Godot 4, GDScript, Mobile renderer. First platform: Android.
- Everything uses a futuristic sci-fi look, including icons and interface.
- Aliens are bio-mechanical and attack because they feed on the power core.
- Seven ranks: Recruit, Cadet, Operative, Sentinel, Warden, Commander, Keeper of the Light.
- Currency is the qubit. It buys jets and military vehicles, and comes from missions and automated colony trade. The player picks items to buy and sell in the Market, which sells everything, including weapons and defences.
- Some item prices change during the game, others stay fixed. Fallen colonies pay less and sell their goods cheaper.
- On first launch the player sees a short filler story about how things got this messy.
- Using a bought item needs the matching rank.
- Changing prices: raw goods (ammo, fuel, supplies). Fixed prices: jets, vehicles, weapons, defences.
- Starting loadout: a jet, a turret, 3,500 qubits, a gun (starter energy rifle) and a sword or machete (new melee weapon).
- Story is told by radio. Two endings.

## Open items

None right now.
