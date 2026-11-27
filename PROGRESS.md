# Progress

Lighthouse is built in stages. After each stage this file and `CHANGELOG.md` are updated and a full project zip is delivered.

**Current stage:** Stage 5 complete. Next: Stage 6.

| Stage | Goal | Status |
| --- | --- | --- |
| 0 | Repo skeleton, README with logo, shield logo, changelog, progress file | Done |
| 1 | Godot project file, Mobile renderer, `game_manager` and `event_bus` autoloads, test screen | Done (untested in Godot) |
| 2 | Test arena: first-person player, touch joystick and aim area, fire button | Done (untested in Godot) |
| 3 | Energy rifle and the first enemy (scout) with basic AI | Done (untested in Godot) |
| 4 | Lighthouse base scene, power core and wave defence | Done (untested in Godot) |
| 5 | Missions and the base-attack choice (defend or continue) | Done (untested in Godot) |
| 6 | Rank unlocks for weapons and defences, rank display, Armoury screen | Done (untested in Godot) |
| 7 | Qubits, automated colony trade and the Market screen | Done (untested in Godot) |
| 8 | Smarter aliens: soldier with a thinking AI (flank, retreat, regroup), scaled by player rank | Done (untested in Godot) |
| 9 | Hangar and fighter jet with touch flight controls | Next |
| 10 | Ten colonies, fall and retake, radio story, first-launch intro story | Planned |
| 11 | More enemies (heavy, flyer, Mothership) with the same brain, more weapons, polish, Android export | Planned |

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
- Attacks on the lighthouse hit base health first, then the power core. Core at 0 is game over.
- Base attack during a mission: defend (mission reward lost, repel the attack for points) or carry on (each turret stops 4 attackers, the rest do 60 damage each to the base then core, and cost 10 + 12 per leaked attacker in rank points).
- Rank points come from completed missions and repelled attacks. Base damage persists until repaired with qubits.
- Rank gating: every item has a minimum rank (`data/item_data.gd`). Turret slots = 1 + rank index, so a higher rank runs more turrets (the base scene has 4 spots for now).
- Market: sells everything. Raw goods (ammo, fuel, supplies) change price after each mission (within 50% to 150% of base); other items are fixed. Selling returns 50% of the price. Fallen colonies pay 70% of that and charge 80% when you buy.
- Auto trades: up to 6 orders (auto-buy or auto-sell one unit each), run after every mission with the colony chosen when the order was set.
- Alien intelligence: scouts are instinct only (swarm, never retreat). Soldiers think: tactical (hold range, strafe, shoot, fall back to heal when under 30% health) and, from player rank Sentinel, cunning (flank with allies, shoot while retreating, retreat early when allies are few, threats many or comrades are dying). Soldiers retreat at most twice. Later enemy types get higher intelligence.
- Waves 1 and 2 are scouts only. Soldiers join from wave 3 (15% per wave, up to 60%). In missions, soldiers appear after the first 3 kills, 15% chance per risk level.

## Open items

- Rank thresholds, item prices and unlock ranks are placeholders. Tune after playtesting.
- The machete has no melee code yet.
- Alien AI numbers (retreat thresholds, ranges, accuracy, soldier share) are untested guesses. Report how fights feel.
- Colonies cannot fall yet (Stage 9), so the fallen-colony prices are in place but unused. Raw goods are tradable but nothing consumes them yet.
- Only 4 turret spots exist in the base scene, but slots reach 7 at the top rank.
