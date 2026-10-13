# Craft an Egg — Integration status

How the code maps to the Technical Design Doc (TDD, Oct 13 2026), and every
place it deliberately differs. Balance numbers marked *provisional* in
`src/shared/Config/GameConfig.luau` are logged here.

## Module map

| TDD module | Where it lives |
| --- | --- |
| `Container`, `Scheduler`, `ConfigSchema` | `src/server/Container.luau`, `Scheduler.luau`, `src/shared/Config/ConfigSchema.luau` |
| `PlayerStore` | `src/server/Store/PlayerStore.luau` |
| Services (Data, Wallet, Inventory, Mining, Speed, Upgrade, Craft, EggDirector, Chase, Base, Hatch, Pet) | `src/server/Services/*Service.luau`, `EggDirector.luau` |
| `SpeedSystem`, `ChaseSystem` | `SpeedService:tick`, `ChaseService:tick`, called from the one `Heartbeat` in `init.server.luau` |
| `IncomeSystem` | Inline system in `init.server.luau` (1 s, pays `incomePerSec`) |
| `ReplicationSystem` | `ReplicationService:tick`, last in the scheduler |
| Net layer, rate limiter, reason codes | `src/network.blink` (generated `Network.luau`), `NetworkService.luau`, `Actions.reasons` on the client |
| `Pool`, `SeededWander`, `Signal` | `src/shared/Util/` |
| World layout (biome path, plots, safe zone) | `src/shared/Util/WorldLayout.luau`: biomes are one path from the lobby toward -Z (Meadow → … → Void), each entrance two wall blocks with a gate. Server and client both read positions here |
| `MiningController` | `src/client/Controllers/MiningController.luau` |
| `TreadmillController` | `TreadmillController.luau` |
| `CraftController` (pot camera + drops) | `CraftController.luau` |
| `MeteorController` | `MeteorController.luau` |
| `CrashController` | `CrashController.luau` (also the owner-only prompt and waypoint) |
| `MobRenderController`, `PetRenderController` | `MobRenderController.luau`, `PetRenderController.luau` |
| `HudController`, `ShopController` | Vide screens under `src/client/UI/Screens/`; prompts for pot, shop and pads in `BaseController.luau` |
| Client pools, effects, camera owner | `Controllers/Visuals.luau` |

Blink allows one listener per event, so `src/client/ClientEvents.luau`
connects each event once and fans it out through `Signal`s. Nothing else may
call `Network.<Event>.On`.

## Deliberate differences from the TDD

| TDD says | Code does | Why |
| --- | --- | --- |
| Dirty fields (cash, speed, node HP…) on `StateDelta` (unreliable, 10 Hz) | Dirty fields on `StateSync` (**reliable**), diffed per field at ≤ 10 Hz; mob positions go on `MobDelta` (unreliable, broadcast) | A dropped unreliable packet could leave cash or backpack wrong until the next change. Diffing keeps it small: the 1 s income tick sends `cash` + `serverNow` only |
| One config module per system | One frozen `GameConfig` | Fewer requires; same data, still validated by `ConfigSchema` at boot |
| `PotCam`, `MeteorCam`, `EggSpot`, `MobDen` parts | Computed positions in `World.build` / controllers | Blockout world is generated in code. Swap in parts when the map is built |
| Per-biome ground height grid | Flat ground at Y = 0 | Blockout is flat; reinstate the grid with real terrain |
| Pets animated with `AnimationController` within 80 studs | Anchored part models moved with `BulkMoveTo`, no animation | No pet animation assets exist yet. Never invent asset ids |
| Run animation on the treadmill | Plays the character's own `Animate.run` animation | Uses an animation already shipped with the character |
| Mob/pet models | Blockout part models from code | No art yet; pools are keyed so models can be swapped in one place |
| Robux receipts in the profile | `receipts` field exists; no `ProcessReceipt` handler | No developer products are defined. Add the handler with the first product (grant after save) |
| `Swing { nodeId }`, client names the node; mining via prompts | M1 (pickaxe `Tool.Activated`) sends `Swing {}`; the server finds the nearest node with `GetPartBoundsInBox` (6 × 7 × reach box in front of the root part, node parts only) | Design change: hitbox mining. The client can no longer pick a node at all |
| Crash game: Grow, then Take = stop + carry | One owner-only prompt (E): **Grow → Stop → Collect**. `EggStop` locks the multiplier into a new `Stopped` state; `EggTake` then carries it. No egg buttons on screen | Design change. A `Stopped` egg survives rejoin as `Stopped`; an expired drop also returns as `Stopped` |
| Retries after a crash (open item) | `crash.attempts = 1`: one grow per egg; after a crash, E collects at 1× | Design decision |
| Pot opens within 10 studs; leaving closes it | Pot opens from anywhere (HUD Craft button); no distance checks | Design change |
| Egg status in the HUD | Billboard on the owner's egg: name, live multiplier, value, next E step / distance / drop timer. The 2D egg panel is removed | Design change |
| Meteor camera from a fixed `MeteorCam` part | Chase cam locked beside the falling egg (12 side, 3 up, 8 trailing), shake on impact, 0.8 s hold, then back | Design change |
| 8 plots, hatch pads, `PlaceEgg { eggIndex, padIndex }` | 7 bases (56 × 44) in one row by the gate, split by a walkway. No pads: select an egg in the hotbar (it shows in hand), M1 anywhere on your base sends `PlaceEgg { at }`; server checks own base, 3-stud edge margin, 40-stud reach, 6-stud spacing, `padCount` capacity. Spot saved as an offset from the plot centre | Design change. Set the place's Max Players to 7 |
| Hotbar slot 1 treadmill (Roblox backpack) | Custom hotbar: 1 Treadmill, 2 Pickaxe, 3–9 delivered eggs; selected slot lifted/gold/white outline; re-select puts it away (`Equip { id = "none" }`) | Design change |
| Mobs created per chase, owner-only, pathfinding, leash at the biome edge | Every biome's mobs always exist at fixed homes behind the egg spots (`WorldLayout.mobs`), drawn by every client. Carrying a biome's egg makes that biome's mobs chase you in a straight line (no pathfinding, no collision) until you reach the lobby or are caught; then they walk home. `MobDelta` broadcasts only mobs away from home | Design change |
| Caught: player teleported to the lobby spawn | Caught: the egg drops where you stand; you are knocked away from the mob (`Config.hit`: 70 studs/s out, 45 up) and ragdoll for 5 s (server swaps Motor6Ds for ball sockets, `src/server/Ragdoll.luau`; the client goes to the Physics state and applies the knockback), then get up in place. Pick-up is refused while down | Design change |
| Pot slots as a sparse table | Snapshot sends a dense 5-slot array with `false` for empty | Remotes truncate arrays at the first `nil` |

## Provisional balance (needs design sign-off)

- `pickaxe.power` per tier (`{2, 8, 24, 72, 200, 600, 1800}`), level costs.
- 14 of the 21 material names/values (prototype supplied the rest).
- Hatch odds rows at luck 0/1/2.
- Economy pace (Oct 13): pet income 5 / 25 / 120 / 600 / 3K / 15K / 75K per biome; pickaxe tiers 2.5K / 75K / 400K / 2M / 10M / 50M; treadmill, backpack, hatch-slot and pet-slot price tables; hatch 10–300 s; node regrow 15 s; treadmill tick 1 s. Roughly a minute to Stone, then 6–7 minutes per tier. Global knobs: `Config.tuning` (price, income, hatchTime).
- `crash.retries = 1` → two growth attempts per egg (TDD open item).

## Open items carried from the GDD

Retry count after a crash, selling materials, biome teleport pads, upgrade
costs, Robux products.

## Verifying

```powershell
stylua --check src/
rojo build default.project.json -o CraftAnEgg.rbxl
lune run tests/run.luau
```

`tests/run.luau` loads the built place, runs the server services headless and
mounts every Vide screen. It does not run the 3D controllers (they need a live
client), so play-test in Studio for: pot camera and drops, meteor follow and
shake, treadmill model and "+N Speed", chase mobs, pet wander, bystander egg
growth.
