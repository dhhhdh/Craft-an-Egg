# Player data (ProfileStore)

| | |
| --- | --- |
| Store name | `CraftAnEgg_v1` |
| Key | `Player_<UserId>` (e.g. `Player_123456`) |
| Template / type | `src/shared/Types/Profile.luau` |
| Owner | `DataService` (only writer; session-locked, reconciled with the template on load) |

## Saved fields

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `version` | number | 1 | Schema version |
| `cash` | number | 0 | Money |
| `speed` | number | 0 | Treadmill points (never reset); WalkSpeed is derived from it |
| `pickaxe` | `{ tier, level }` | `{ 1, 0 }` | Tier 1–7 (Wood → Void), level 0–5 |
| `treadmillLevel` | number | 1 | 1–10 |
| `backpackCap` | number | 30 | 30 / 40 / 50 / 60 |
| `backpack` | `{ [materialId]: count }` | `{}` | Mined materials |
| `worldEgg` | `Egg?` | nil | The crafted egg not yet delivered (max one) |
| `eggs` | `{ Egg }` | `{}` | Delivered eggs: the hotbar egg slots (3–9) |
| `padCount` | number | 3 | Hatch slots (eggs hatching at once), 3–6 |
| `pads` | `{ { egg: Egg?, hatchAt: number?, pos: { x, z }? } }` | `{ {}, {}, {} }` | Eggs placed on the base; `hatchAt` is `os.time()`, `pos` is the offset from the base centre |
| `petCap` | number | 8 | 8 → 30 |
| `pets` | `{ { uid, petId, eggValue } }` | `{}` | Owned pets |
| `discovered` | `{ [petId]: true }` | `{}` | Pet index |
| `receipts` | `{ string }` | `{}` | Last Robux receipt ids (reserved, no products yet) |
| `stats` | `{ crafted, crashes, caught, bestMult }` | zeros, `bestMult = 1` | Lifetime stats |

`Egg` = `{ biomeId: 1–7, baseValue: number, multiplier: number, state: string, landPos: { x, y, z }, retriesLeft: number? }`.
`worldEgg.state` is saved as `Landed`, `Stopped`, `Carried` or `Dropped` (`Growing`/`Falling` are saved as `Landed` at 1×). On rejoin a `Carried`/`Dropped` egg returns to `Landed` at its crater, keeping its multiplier; `Stopped` stays `Stopped`.

**Never saved** (session only, `PlayerStore`): node HP, pot slots, mobs, crash point, held hotbar item, running.

## When it saves

Craft, take/stop/drop/deliver, place, hatch, sell, every purchase, every 60 s, on leave, and on server shutdown.

## Checking that data saved

1. **In game:** the HUD (bottom right) shows `Saved Ns ago`, from ProfileStore's `OnAfterSave`, so it only updates after the write actually lands. `Not saved yet` (red) means no confirmed save this session. The first one comes within 60 s, or immediately after any value action.
2. **Studio Output:** every confirmed save prints
   `[CraftAnEgg] Saved Player_<id> (mock|live): cash …, pets …, eggs …, materials …`.
3. **Studio is MOCK by default:** nothing persists between Play sessions. To test real saving:
   - Game Settings → Security → *Enable Studio Access to API Services* (the place must be published).
   - Set `"UseLiveDataInStudio": true` in `src/server/Services/DataService.meta.json` (Rojo syncs it).
   - Play, do something, stop, Play again: the values should come back, and the log should say `live`.
4. **Read the live record directly** (Studio command bar, edit mode, API access on). Replace the id with your user id:

```lua
local ProfileStore = require(game.ServerScriptService.ServerPackages.ProfileStore)
local profile = ProfileStore.New("CraftAnEgg_v1"):GetAsync("Player_123456")
if not profile then
	print("No saved data for this player")
else
	print("Last saved:", DateTime.fromUnixTimestampMillis(profile.KeyInfo.UpdatedTime):ToIsoDate())
	print(game:GetService("HttpService"):JSONEncode(profile.Data))
end
```
