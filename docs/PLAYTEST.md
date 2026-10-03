# Studio playtest checklist

The automated suite covers logic, geometry, odds, saving math and instance construction. These
items need a real Roblox Studio session. Use **Test → Start** with 2–3 players for the
multiplayer items. The chat commands from the README (`/money`, `/grow`, `/event`, `/offline`,
`/reset`) speed this up.

## First-time experience (target: first upgrade within 60 s)
- [ ] Spawn in the hub facing the lanes; the world is already built (no falling through the ground).
- [ ] Your lane sign shows your name; a gold arrow bobs over your cart; the hint says RIDE YOUR RAMP.
- [ ] "Enter Cart" (E / tap) is visible only on your own lane.
- [ ] The lift cable runs from your pad to the start gate; the cart zips up it.
- [ ] READY? → GO!, SPEED climbs (+1 popups), the progress bar fills, and boost pieces show bigger popups.
- [ ] Launch: the DISTANCE panel replaces SPEED and counts up live; the camera pulls back.
- [ ] Landing: dust, a bounce, reward "+$…", "You reached the …!" when past a landmark; then you return to your pad.
- [ ] The hint changes to UPGRADE YOUR RAMP; the Upgrades button shows a red badge.
- [ ] Buying any upgrade makes the timer show about 00:05; a new piece appears with a flash.
- [ ] A second ride beats the first.

## Ride robustness
- [ ] Loops: the cart goes upside down smoothly; the camera does not roll or flip.
- [ ] Spirals, jumps (gap), big drops, banked curves look correct; no jitter at high speed.
- [ ] Reset the character mid-ride → "Ride cancelled", no reward, normal respawn.
- [ ] Leaving mid-ride → the cart is cleaned up; the lane frees and the display cart returns.
- [ ] Spam the prompt → only one ride starts.
- [ ] Other players see your cart move along your ramp and fly (replication looks acceptable).

## Growth, RNG and events
- [ ] NEXT PIECE counts down; pieces grow at the top while you watch; a full ramp switches to NEXT ROLL.
- [ ] `/grow 60` → the ramp fills its lane without clipping into hedges or other lanes; supports reach the ground.
- [ ] Legendary or rarer → banner with "1 IN N"; Mythic/Secret → server announcement (2 players).
- [ ] Mutations look distinct (Golden / Giant / Rainbow cycling / Glitched jitter / Void particles).
- [ ] `/event Luck10x` → banner with countdown; the Ramp menu odds change; it ends cleanly.

## Saving and offline (enable Studio API access)
- [ ] Leave and rejoin → cash, upgrades, ramp pieces and best distance persist exactly.
- [ ] `/offline 120` → the Welcome Back panel lists pieces by rarity; the pieces reveal one by one.
- [ ] Stop the server while playing (BindToClose) → data is saved on rejoin.
- [ ] Join the same account in two servers → the second waits for the session lock, and no duplication happens.

## UI and devices (Device Emulator)
- [ ] Phone landscape, tablet, small laptop, 1080p: nothing overlaps; the centre stays clear during rides.
- [ ] Narrow screens show icon-only navigation; buttons are comfortably tappable.
- [ ] The notification stack never covers navigation buttons.

## Performance
- [ ] 6 players with full ramps: check the MicroProfiler / F9 Stats on a low-end emulated device.
- [ ] VFX (particles/lights) switch off on far ramps (watch from the hub vs. near the lips).

## Before publishing
- [ ] Game Settings → Places → Max Players = 6.
- [ ] Replace placeholder sounds (AudioConfig) and add icon/thumbnail art.
- [ ] Set `GameConfig.Debug.AllowOwnerCommands = false` (the default).
