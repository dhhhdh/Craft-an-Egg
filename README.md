# CraftAnEgg

Roblox project using Rojo, Rokit, Wally, Blink, ProfileStore, and Vide.

## First-time setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then restart the terminal if prompted.
2. Install the pinned tools and packages:

   ```powershell
   rokit install
   wally install
   blink src/network
   ```

3. Install the Rojo Studio plugin once:

   ```powershell
   rojo plugin install
   ```

4. Build or live-sync the experience:

   ```powershell
   rojo build -o CraftAnEgg.rbxl
   rojo serve
   ```

Rokit is the primary tool manager. `aftman.toml` mirrors the tool pins for contributors who still use Aftman, but Aftman itself is archived.

## Packages

- Shared/client: `require(ReplicatedStorage.Packages.Vide)`
- Server-only: `require(ServerScriptService.ServerPackages.ProfileStore)`

Edit `src/network.blink`, then run `blink src/network` to regenerate the client, server, and shared network modules.
