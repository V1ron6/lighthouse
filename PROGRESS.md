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
| 9 | Comrades: your own soldiers at the lighthouse (fight beside you, hold the base while you are away) | Done (untested in Godot) |
| 10 | Hangar and fighter jet with touch flight controls | Done (untested in Godot) |
| 11 | Ten colonies, fall and retake, radio story, first-launch intro story, two endings | Done (untested in Godot) |
| 12 | Heavy and flyer aliens with the thinking AI; flyers hunt the jet | Done (untested in Godot) |
| 12b | Placeholder sound effects and a sound manager (`Sfx`) | Done (untested in Godot) |
| 13 | Mothership boss, machete and more weapons, the full 20 missions | Next |
| 14 | Polish (real menu, music, icons and font, art pass), Android export | Planned |

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
- Comrades: your own soldiers, stationed at the lighthouse. You start with 2. They fight beside you in base defence, and while you are away on a mission each stops 2 attackers (turrets stop 4). Slots = 2 + rank index. Bought in the Market (900 qubits). A downed comrade returns to its post after 25s, so none are lost for good. Missions are solo.
- Comrade AI: picks targets (enemies nearest the lighthouse first, weakest first), keeps range and strafes, falls back behind the lighthouse below 35% health and heals. Aliens attack comrades that get close, and cunning soldiers count comrades as threats.
- Jet: a hangar and launch pad stand beside the lighthouse in base defence. Walk to the pad, press Board (or E), and fly. Stick turns and pitches (push up = nose up), throttle is automatic, the fire button shoots twin cannons with aim assist. Land back at the pad with the Land button. Needs the fighter jet in your inventory and the rank to use it. Missions are on foot, so no jet there.
- While you are in the jet, aliens do not target you (your character is parked). The jet cannot be hurt until flyers arrive in a later stage.
- Colonies: after every ended mission a colony may fall (25% after a win, 35% after a failed or abandoned mission, at most 5 down at once). A fallen colony is retaken automatically after 3 won missions, with a radio message. Fallen colonies use the cheaper trade prices.
- Story: intro pages on first launch, 10 once-only radio messages (missions won and rank-ups), plus dynamic colony lost and retaken transmissions, all kept in the Radio log. At Keeper of the Light the hub shows FINAL TRANSMISSION with two choices: Sever the Core (The Dark Dawn) or Keep the light (The Eternal Watch).
- Heavy: slow, 220 health, always cunning. Armour halves damage, but the chest core glows for 1.2s after each shot it fires and then hits do double. Heavies join from wave 5 (up to 25%).
- Flyer: 45 health, circles above its target then dives and strafes, breaks off, retreats to heal when hurt. Hunts the jet first. Flyers join from wave 4 (up to 30%).
- The jet now has 200 hull. At 0 it is shot down: you are put back on the pad and the jet needs 20s of repairs. A normal landing repairs it fully.
- Sound: 11 generated placeholder sounds in `audio/sfx/` (rifle, turret, alien bolt, hit, death, jet cannon, base alert, radio, click, promotion, base hum). Replace any file with a better one of the same name. `Sfx.play("name", volume_db)` plays one. Icons, models, textures, fonts, music and voiced radio are still empty.

## Open items

- Rank thresholds, item prices and unlock ranks are placeholders. Tune after playtesting.
- Sounds are crude synth placeholders. Godot imports the .wav files the first time you open the project.
- The machete has no melee code yet (planned for Stage 13).
- Heavy and flyer numbers are untested guesses, as are the spawn shares.
- Retaking a colony is automatic. If you would rather fight a special retake mission, say so.
- Story text is a first draft (original, written by Claude). Edit `data/story_data.gd` freely.
- Only 3 of the planned 20 main missions exist.
- The hub is a test screen with a debug column; a proper menu comes in the polish stage.
- Jet handling (speed, turn rates, aim assist cone, camera) is a first guess. Report how it feels on the phone. The interceptor and gunship are in the Market but not flyable yet.
- Comrade numbers (damage, health, slots, price, starting 2) are guesses. Starting with 2 comrades goes beyond the stated loadout, so say if you want to start with none.
- Alien AI numbers (retreat thresholds, ranges, accuracy, soldier share) are untested guesses. Report how fights feel.
- Colonies cannot fall yet (Stage 9), so the fallen-colony prices are in place but unused. Raw goods are tradable but nothing consumes them yet.
- Only 4 turret spots exist in the base scene, but slots reach 7 at the top rank.
