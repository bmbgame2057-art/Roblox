# Grow a Ramp: project memory for Claude

Read this first. It carries everything from the first build session (a cloud session, 2026-10-03)
so any new session, local or cloud, can continue without the old chat.

## What this is
A Roblox progression game: your ramp grows from RNG-rolled modular track pieces (also while
offline), you ride it with +1 speed per piece, then launch toward a landscape with real distance
landmarks. The one objective is GO FARTHER.

- **Full original brief (verbatim):** `docs/ORIGINAL_PROMPT.md`. It is the source of truth for
  scope, style and priorities.
- **Concept art (visual target):** `docs/reference/01..04-*.webp`. Look at these before doing
  any visual work.
- **Player-facing overview, structure, config guide:** `README.md`
- **Balance numbers / simulator output:** `docs/BALANCE.md`
- **Studio playtest checklist:** `docs/PLAYTEST.md`

## Current status (end of session 1)
Everything below is built, pushed to branch `claude/roblox-massive-prompt-idea-u7pwss`, and
packaged in `build/GrowARamp.rbxl` (scripts plus the baked world; terrain is generated on first Play).

Working and tested headlessly: the modular track system (29 pieces, 7 rarities, 5 mutations),
luck/odds, ramp growth (online and offline), the server-authoritative ride/launch/reward,
4 upgrades, session-locked DataStore saving, 5 events, leaderboards, notifications, onboarding,
the Welcome Back panel, debug chat commands, and the procedural world (hub, 6 fanned lanes,
creek/road/town/canyon/mountain).

### ⚠️ User feedback after opening it in Studio (top priority)
> "I can see the idea is there but the map and UI are the worst things I've ever seen."

The gameplay foundation is fine. **The visuals are not acceptable.** Why:
- The map, props, carts and track pieces are stacks of basic Parts made by code (`src/server/World/*`).
  They read as a Studio blockout, which the brief explicitly forbids for final visuals.
- The UI was built in code (`src/client/UI/*`) without Figma and without anyone looking at it in
  Studio.
- Session 1 ran in a **cloud container**. The network policy blocked `mcp.figma.com` (403), no
  3D-modeling tool was connected, and Roblox Studio on the user's Mac was unreachable. So it
  could not design, model or see anything.

### Next session goals (in order)
1. **Confirm tools.** Check that Figma (and any Roblox Studio MCP / modeling tool the user has) are
   actually connected before starting. If not, say so plainly and give the exact fix.
2. **UI redesign.** Design the HUD and menus in Figma, following `docs/reference/` and brief
   sections 29–32 (light, compact, mobile-first, money top-left, nav top-right, SPEED hero while
   riding, DISTANCE hero in flight, stacked right-side notifications). Then rebuild
   `src/client/UI/*` to match. Keep `UIConfig.luau` as the token source.
3. **Real 3D art.** Replace the part-built visuals with proper low-poly models: track pieces
   (smooth decks, rails, supports), carts, hub buildings, houses, trees, rocks, signs, landmarks.
   The code already supports drop-in models: `ServerStorage.Assets.TrackModels` (Model named by
   piece id, with an `Entry` attachment), `CartModels/DefaultCart`, and `WorldAssets` (see
   README → Final art pipeline). For the track, also consider generating smooth deck meshes from
   the same path samples (EditableMesh) so every steer/mirror variant stays exact.
4. Look at the result in Studio (screenshots) and iterate until it matches the concept art.
5. Then work through `docs/PLAYTEST.md`.

## How the user works
- Wants work actually done, not plans. Few questions; make reversible decisions yourself.
- Not deeply technical: explain settings and steps in plain language, one step at a time.
- Uses Roblox Studio on a Mac. In session 1 they opened blank Baseplates before finding the place
  file, so always say exactly which file to open and how.

## Tech setup
- Rojo 7 project (`default.project.json`); Luau in `src/shared` (ReplicatedStorage.Shared),
  `src/server` (ServerScriptService.Server), `src/client` (StarterPlayerScripts.Client).
- Tools used: rojo, lune (tests and place export), luau-lsp (with Roblox `globalTypes.d.luau`),
  selene (`roblox_min.yml` std, because the full std download was blocked), stylua.
- `./tools/check.sh` runs format, lint, typecheck (set `ROBLOX_TYPES`), the 65 Lune tests, and
  rebuilds `build/GrowARamp.rbxl` (`lune run tools/build-place.luau`).
- Balance sim: `lune run tests/tools/simulate.luau 60 <seed>`. Preview renders:
  `lune run tests/tools/export_preview.luau && python tests/tools/render_preview.py`.

## Architecture notes and gotchas
- **Config-first:** all balance numbers live in `src/shared/Config` and `src/shared/Definitions`.
- **Shared logic is pure and tested:** TrackGeometry, RampLayout, RampGenerator, RarityRoller,
  RideSim, Economy, OfflineGrowth, PieceCodec. The server, the tests and the simulator use the
  same code.
- **Ramps grow backward** from a fixed launch lip on one shared launch line (radius 1300 around
  the lane fan focus), so landmark distances are true for every lane. Players board at the hub
  pad and ride a lift cable (Bezier, the same curve as the Beam) up to the ramp top.
- **Server-authoritative rides:** the server builds the plan and pays at the planned landing
  time. The client animates the cart, which is welded to the rider, massless and client-owned.
- `SessionService` orders join/leave; `RampService` runs all rolls for a player on one worker
  thread and pauses while the player is riding.
- **Lune quirks** (handled in `tests/harness`): Lune's `CFrame.lookAt` is inverted vs Roblox
  (the harness patches it). `CollectionService:AddTag` needs a stub. `Instance.Position` is not
  readable in Lune, so builders use CFrame.Position.
- **Roblox gotchas found:** `Terrain.Decoration` is not scriptable. `Kit.Panel`'s `Radius` is a
  Kit option and must never be set on the Frame (it once would have crashed the HUD).
- The world/UI specs execute the real builders against Roblox's reflection DB, so keep that
  coverage when replacing visuals.
