# Original brief (verbatim, from the user)

Reference images: `docs/reference/` (01 overview/map/HUD, 02 track pieces & mutations,
03 gameplay riding, 04 starter world layout).

---

You are my lead Roblox developer, game designer, systems designer, technical architect, UI/UX designer, environment designer, and QA engineer.

I want you to build a complete Roblox game from scratch with the working title:

GROW A RAMP

Use the attached concept images as visual references for:
- overall map composition
- player ramp lanes
- central hub
- distance landmarks
- HUD hierarchy
- track-piece art direction
- rarity presentation
- mutation appearance
- overall visual quality

The images are references, not exact blueprints. Improve them where necessary while preserving the intended direction.

I am using:
- Claude Code / Claude Work
- Roblox Studio
- a connected Figma plugin
- a connected design/modeling plugin

Use these tools actively where appropriate.

Do NOT merely explain what could be built.

Actually build the project, create/edit files, use available connected tools, review the result, test what you can, and continue through the development plan.

If a tool is unavailable, do NOT pretend to use it. Give me the exact manual action required and continue with everything else that can be completed.

Do not repeatedly ask me minor questions.

If a decision is reversible and does not fundamentally change the game, make the best practical decision yourself and continue.

==================================================
1. HIGH-LEVEL GAME CONCEPT
==================================================

This should be a simple, highly replayable Roblox progression game built around:

- offline growth
- heavy RNG / luck
- incremental progression
- +1 speed
- physical visible progression
- satisfying cart rides
- ridiculous launches
- social comparison
- extremely simple controls
- fast progression
- rare moments worth clipping

The game must be understandable within roughly 5 seconds.

The basic fantasy is:

"My ramp keeps growing. I get lucky with insane track pieces. I ride down it faster and faster, then I get launched farther than everyone else."

The single clearest objective is:

GO FARTHER.

Everything in the game should support that objective.

==================================================
2. CORE GAMEPLAY LOOP
==================================================

Every player owns a personal ramp.

The ramp begins very small.

Over time, it automatically grows by generating modular track pieces.

The ramp continues to make limited progress while the player is offline.

Every generated piece is an RNG roll.

Most pieces are basic.

Rare pieces can provide:
- stronger speed gains
- reward multipliers
- dramatic geometry
- loops
- drops
- jumps
- launchers
- portals
- unique VFX

The player enters a cart and rides down their ramp.

While riding:

- each normal track section gives +1 current-run speed
- special pieces can give larger speed boosts
- rare pieces can increase rewards
- unusual track geometry makes the ride visually exciting

At the end of the ramp, the player launches into the distance.

Distance determines their reward.

They then spend currency on:

- Luck
- Ramp Growth Speed
- Base Speed
- Offline Growth Time

The loop is:

RAMP GROWS
→
NEW PIECES ARE REVEALED
→
RIDE
→
GAIN SPEED
→
HIT SPECIAL PIECES
→
LAUNCH
→
MEASURE DISTANCE
→
EARN MONEY
→
UPGRADE
→
RAMP BECOMES LONGER / LUCKIER
→
REPEAT

==================================================
3. DESIGN PHILOSOPHY
==================================================

This is intentionally a simple Roblox game.

Do NOT turn it into:

- an RPG
- a combat game
- a pet simulator
- a crafting game
- a complicated vehicle simulator
- a quest-heavy game
- a story game
- a large tycoon
- a complicated racing simulator

The game should get depth from:

- RNG
- physical visual progression
- increasingly ridiculous speed
- increasingly ridiculous launches
- rare track pieces
- mutations
- world progression
- social comparison
- offline growth

Prioritize:

FUN over complexity

VISIBLE PROGRESSION over menus

STABILITY over realistic physics

RNG EXCITEMENT over RNG clutter

FAST FEEDBACK over slow grinding

FINISHED POLISH over feature count

==================================================
4. FIRST-TIME PLAYER EXPERIENCE
==================================================

A brand-new player should:

1. Spawn in the central hub.

2. Immediately see their ramp lane.

3. See neighboring players' ramps so they understand what progression can become.

4. Receive an extremely short prompt:

RIDE YOUR RAMP

5. Walk a short distance to their cart.

6. Enter it.

7. Ride a small starter ramp.

8. Watch their speed increase.

9. Launch.

10. See their distance clearly.

Example:

247 STUDS

11. Receive money.

12. Receive the next short instruction:

UPGRADE YOUR RAMP

13. Buy one upgrade.

14. See or receive another generated track section quickly.

15. Ride again and beat their first distance.

The first satisfying progression should happen within the first minute.

Do NOT use giant tutorial walls or long explanation screens.

After the first upgrade, show something simple such as:

NEXT PIECE IN 00:18

That should teach the core game.

==================================================
5. STARTER MAP OVERVIEW
==================================================

The first world must feel like a polished game world, not a green baseplate containing ramps.

Theme:

BACKYARD / SUBURBAN WORLD

The overall layout should be:

                   DISTANCE / LAUNCH LANDSCAPE

Ramp 1  ─────────────────────────────────►
Ramp 2  ─────────────────────────────────►
Ramp 3  ─────────────────────────────────►
Ramp 4  ─────────────────────────────────►
Ramp 5  ─────────────────────────────────►
Ramp 6  ─────────────────────────────────►

                     CENTRAL HUB

The hub sits behind the ramp starts.

Players move:

SPAWN
→
RAMP
→
RIDE
→
LAUNCH
→
RETURN / UPGRADE
→
RIDE AGAIN

Do not make players walk unnecessarily long distances between these actions.

==================================================
6. CENTRAL HUB
==================================================

Create a compact but polished central hub.

It should feel like an actual place rather than a lobby filled with floating UI.

Include:

- player spawn area
- upgrade station
- leaderboard area
- world portal area
- ramp access
- simple physical signage
- visual centerpiece

Possible environmental elements:

- stylized suburban building
- plaza
- fountain
- benches
- small shops
- low-poly trees
- fences
- lamp posts
- paths
- decorative carts
- small stands
- leaderboard structure
- world portal structure

Do NOT use:
- huge floating words
- giant hovering area labels
- rows of giant tutorial boards
- random blocky Roblox Studio structures

Use:
- physical signs
- modeled signs
- landmarks
- icons
- subtle proximity prompts

==================================================
7. PLAYER RAMP LANES
==================================================

Create approximately 6 player ramp plots per server for the initial design unless server architecture suggests another sensible number.

Each player receives one lane.

Each lane must include:

- clear ownership
- player name / identity
- start platform
- cart spawn
- ramp-growth origin
- sufficient width
- sufficient separation
- room for vertical growth
- track-generation boundaries

The lanes should be mostly parallel or gently fan outward.

Players must be able to see neighboring ramps.

This visual comparison is important.

A beginner should be able to see:

a tiny basic wooden ramp

next to:

a huge ramp containing:
- loops
- glowing boosts
- rainbow sections
- giant drops
- golden sections
- void sections

Do not isolate every player behind walls.

==================================================
8. DISTANCE / LAUNCH LANDSCAPE
==================================================

All ramps should generally launch toward one large landscape.

This area should visually communicate increasing distance.

Do not make the landing zone an empty flat field.

Use actual environmental landmarks.

Suggested progression:

500 studs
Creek

1,000 studs
Road

2,500 studs
Town edge

5,000 studs
Canyon

10,000 studs
Mountain

Future milestones can become more absurd.

Players should be able to recognize:

"I reached the road."

"I finally reached the town."

"I made it past the canyon."

This gives the distance number physical meaning.

Use subtle markers if needed, but do not rely on giant floating numbers.

==================================================
9. STARTER WORLD ENVIRONMENT
==================================================

Use:

- colorful grass
- stylized trees
- fences
- sidewalks
- houses
- roads
- gardens
- lamp posts
- rocks
- creeks
- bridges
- hills
- distant neighborhoods
- background mountains
- decorative scenery

The world should be readable from:

- ground level
- the start platform
- during the cart ride
- during high-speed movement
- high in the sky during launches

This means the aerial composition matters.

Use:

- roads
- rivers
- neighborhoods
- cliffs
- color regions
- forests
- large landmarks

to make the world look intentional from above.

Do not make the entire world flat.

Use controlled elevation changes and surrounding terrain.

Keep the ramp lanes mechanically clear even if surrounding terrain is more detailed.

==================================================
10. MAP ART DIRECTION
==================================================

Use the connected design/model plugin for important visible environment assets.

The visual style should be:

- stylized
- colorful
- toy-like
- low-poly
- clean
- slightly exaggerated
- readable from far away
- Roblox-friendly
- optimized

Avoid:

- photorealism
- random asset-pack appearance
- excessively blocky placeholder buildings
- giant floating text
- giant neon signs everywhere
- excessive particle effects
- overly detailed geometry

Important final assets should be modeled properly.

Use Roblox Studio Parts primarily for:

- invisible collisions
- triggers
- spawn regions
- utility geometry
- testing placeholders

Final visible structures should not look like Studio blockouts.

==================================================
11. FUTURE WORLDS
==================================================

The overall gameplay layout stays familiar:

HUB
→
RAMP LANES
→
LAUNCH LANDSCAPE

but every world should look physically different.

Potential worlds:

BACKYARD
Suburban houses, grass, roads, creek

CITY
Skyscrapers, highways, rooftops, signs

DESERT
Dunes, rock arches, canyon systems

SPACE
Floating islands, planets, asteroid belts

MOON
Craters, moon bases, low-gravity presentation

VOID
Dark floating structures and surreal cosmic scenery

Do NOT build all of these during MVP.

Build one polished starter world.

Architect the game so additional worlds can be added cleanly later.

==================================================
12. MODULAR TRACK SYSTEM
==================================================

The ramp is the central progression object.

Build it from modular track pieces.

Every piece needs standardized connection rules.

Each track piece definition should support data such as:

ID
Name
Model
Rarity
Weight
TrackLength
HeightChange
DirectionChange
SpeedModifier
RewardMultiplier
WorldRequirement
Tags
EntrySocket
ExitSocket
MutationCompatibility

Use standardized:
- track width
- cart clearance
- socket orientation
- origins
- rail width

When adding a piece:

1. Find the previous piece's exit transform.
2. Roll an eligible piece using rarity and Luck.
3. Align the new piece's entry socket.
4. Validate geometry.
5. Reject clearly impossible or invalid placements.
6. Place the piece.
7. Save compact piece data.

Do not generate tracks that:

- repeatedly overlap
- reverse into previous track
- clip horribly into terrain
- create impossible transitions
- break cart movement

RNG should affect the ramp while rules maintain usability.

==================================================
13. TRACK RARITIES
==================================================

Use:

COMMON
UNCOMMON
RARE
EPIC
LEGENDARY
MYTHIC
SECRET

All rarity weights must live in configuration.

Do not scatter numbers across scripts.

Luck should influence rarity odds.

Luck should improve odds gradually.

Higher Luck should NOT instantly remove Common pieces.

==================================================
14. STARTER TRACK PIECES
==================================================

COMMON

Straight Track
Slight Downhill
Small Hill
Gentle Curve

UNCOMMON

Long Straight
Small Speed Pad
Steep Downhill
Small Drop

RARE

Strong Speed Boost
Large Drop
Banked Curve
Small Jump

EPIC

Huge Drop
Double Boost
Large Jump
Spiral Section

LEGENDARY

Golden Track
Massive Speed Pad
Loop
Reward Multiplier Track

MYTHIC

Rainbow Track
Extreme Drop
Giant Launcher
Triple Boost

SECRET

Void Track
Portal Track
Impossible Loop
Massive Gravity Drop
Secret Launcher

Do not require all of these for the first MVP.

Create approximately 10 useful pieces initially and expand once the system is proven.

==================================================
15. RNG PRESENTATION
==================================================

Rare pieces should feel exciting.

Example:

SECRET TRACK GENERATED

VOID LOOP

1 IN 75,000

Use controlled:

- sound
- animation
- particles
- glow
- notification

Only extremely rare rolls should be server-announced.

Do not spam announcements.

Rare odds shown to players must match the actual system.

Keep RNG server-authoritative.

==================================================
16. TRACK MUTATIONS
==================================================

Any eligible track piece can independently roll a mutation.

Start with:

GOLDEN
RAINBOW
GIANT
GLITCHED
VOID

Possible effects:

GOLDEN
Higher reward multiplier

RAINBOW
Speed + reward bonus

GIANT
Larger/more dramatic geometry

GLITCHED
Controlled unusual boost + digital VFX

VOID
Extremely rare high-value mutation

Mutations can stack conceptually with rarity.

Example:

Legendary Loop

could become:

Golden Legendary Loop

or:

Void Legendary Loop

Make mutation definitions data-driven.

Do not create separate full models for every rarity/mutation combination unless required.

Prefer materials, scale, colors, particles, lights, and effects where appropriate.

==================================================
17. OFFLINE GROWTH
==================================================

Offline growth is one of the core reasons to return.

Save:

- last logout timestamp
- ramp growth speed
- offline-duration cap
- necessary ramp progression values

When the player returns:

calculate how many pieces grew while away.

Do not simulate every offline second.

Example:

WELCOME BACK

YOUR RAMP GREW 14 PIECES

9 Common
3 Uncommon
1 Epic
1 LEGENDARY

Then generate/reveal those pieces.

Starting offline cap could be approximately:

2 hours

with upgrades extending it to:

4
8
12
etc.

Exact numbers belong in configuration.

Protect against:

- system clock abuse where possible
- reconnect abuse
- duplicate generation
- duplicate rewards
- absurd timestamp values

==================================================
18. RAMP GROWTH WHILE ONLINE
==================================================

Ramp pieces should also generate while the player is online.

Show a compact timer:

NEXT PIECE
00:18

Growth Speed upgrades reduce generation time.

When a new piece is generated:

- place it physically
- show rarity feedback
- update ramp state
- save when appropriate

Rare pieces should be noticeably more exciting.

==================================================
19. +1 SPEED SYSTEM
==================================================

The ride should have a satisfying +1-style number increase.

Separate:

BASE SPEED

from:

CURRENT RUN SPEED

Base Speed comes from permanent upgrades.

Current Run Speed resets each ride.

Each normal piece passed can add approximately:

+1 SPEED

Special pieces can provide:

+5
+10
+25
temporary multipliers
boosts

Exact values belong in configuration.

During rides, the SPEED number should be visually important.

Watching it climb is part of the game.

==================================================
20. CART / RIDE SYSTEM
==================================================

Keep controls simple.

The player enters a cart.

Forward movement should be mostly automatic.

This is not a driving game.

The ride should feel:

- smooth
- quick
- stable
- increasingly dramatic

Avoid uncontrolled Roblox physics.

Use guided movement, constraints, or another reliable approach.

The track geometry should influence movement without making the cart constantly derail.

Handle:

- curves
- hills
- drops
- loops
- boosters
- launchers

The camera should adapt to speed.

Possible effects:

- slight FOV increase
- wind
- speed lines
- wheel effects
- subtle shake

Avoid nausea and excessive shaking.

==================================================
21. LAUNCH SYSTEM
==================================================

The launch is the main payoff.

At the final ramp piece, transition the cart/player into a controlled launch.

Launch power should derive from current ride speed.

Do not simply let unstable physics fling the cart randomly.

Track:

live horizontal distance from the launch point.

Show:

384
529
781
1,023 STUDS

When landing:

NEW RECORD

1,437 STUDS

Calculate reward from a configurable formula using:

Distance
Track multipliers
Mutation bonuses
World multiplier
Other temporary bonuses

==================================================
22. RETURN / REPEAT FLOW
==================================================

After landing:

- show distance
- show reward
- show record if relevant
- provide quick return path

Do not make the player manually walk 10,000 studs back.

Use a clean return/teleport flow back to hub or ramp start.

The next ride should be available quickly.

==================================================
23. ECONOMY
==================================================

Primary currency comes from launch distance.

Do not create too many currencies.

For MVP:

ONE main currency.

Possible future premium/event currency only if needed later.

All formulas must be configurable.

Avoid extreme inflation immediately.

Progression should move quickly early and slow gradually.

==================================================
24. UPGRADES
==================================================

Start with four primary upgrades:

LUCK

Improves rarity odds.

RAMP GROWTH SPEED

Generates track pieces faster.

BASE SPEED

Starts each ride faster.

OFFLINE TIME

Increases how long ramp growth continues while away.

Possible later upgrade:

REWARD MULTIPLIER

Do not add 20 upgrade categories.

Prices should scale.

All formulas belong in config modules.

==================================================
25. PRESTIGE / REBUILD SYSTEM
==================================================

Do NOT prioritize this before MVP is fun.

Later add a prestige mechanic with a name like:

REBUILD RAMP

Potential requirement:

reach a major distance
or
reach a certain ramp length/world

It can reset:

- ramp
- some upgrades
- some progression

while permanently increasing:

- Luck
- Growth Speed
- Currency multiplier

Prestige should provide meaningful long-term progression without making the initial game irrelevant.

==================================================
26. SERVER EVENTS
==================================================

Add only after the core system works.

Potential events:

10X LUCK

DOUBLE GROWTH

GOLDEN RUSH

MUTATION STORM

SECRET SURGE

Events should:

- affect the server
- be short
- be clearly announced
- create urgency
- be easy to understand

Do not add complicated event minigames initially.

==================================================
27. SOCIAL / FLEX SYSTEM
==================================================

Social comparison is important.

Players should easily see each other's ramps.

Rare pieces remain physically visible in ramps.

Server displays can later show:

FARTHEST LAUNCH

LONGEST RAMP

RAREST TRACK PIECE

Personal UI should show:

BEST DISTANCE

Extremely rare pieces can produce a server announcement.

Example:

PLAYER JUST GREW A VOID LOOP
1 IN 75,000

Do not spam lower-rarity rolls.

==================================================
28. RETENTION
==================================================

Offline ramp growth should be the primary return hook.

Potential lightweight additions after MVP:

- daily reward
- login streak
- daily Luck boost
- rotating mutation
- limited Secret piece
- weekend Luck event
- playtime reward

Do not cover the game in claim buttons.

==================================================
29. FIGMA / UI DIRECTION
==================================================

Use the connected Figma plugin for final UI design.

The UI must be much cleaner than the previous Stack Everything project.

Avoid:

- giant overlapping panels
- huge mission-style boxes
- thick borders on everything
- permanent notifications
- blocking the center of gameplay

Design mobile-first.

==================================================
30. HUD LAYOUT
==================================================

TOP LEFT

Compact Money display.

TOP RIGHT

Compact navigation:

Upgrades
Ramp
Worlds

Do not make these oversized.

NORMAL STATE

Show a small ramp-growth timer:

NEXT PIECE
00:18

RIDE STATE

Make SPEED the main HUD element.

Example:

SPEED
268

Optionally show:
current distance
best distance

but keep the HUD compact.

LAUNCH STATE

Reduce other information and emphasize:

DISTANCE
1,847 STUDS

RIGHT SIDE

Use temporary stacked notifications:

Legendary Piece Generated
New Record
Offline Growth
Event Active

Notifications should:

- stack vertically
- disappear automatically
- not cover buttons
- not cover the center
- not cover critical gameplay

==================================================
31. UI VISUAL STYLE
==================================================

Use:

- rounded modern panels
- readable typography
- bright but controlled color
- clear icons
- hierarchy
- spacing
- subtle borders
- subtle shadows

Avoid giant black outlines around everything.

The HUD should feel light.

Use contextual UI instead of showing every possible stat simultaneously.

==================================================
32. TRACK / RAMP MENU
==================================================

The Ramp menu can later show:

- current length
- piece count
- rarest piece
- mutation count
- next-generation timer

Do not make the menu mandatory for basic gameplay.

==================================================
33. AUDIO / GAME FEEL
==================================================

Add hooks and later final sounds for:

- piece generated
- rare piece generated
- mutation generated
- entering cart
- ride start
- speed increasing
- boost pad
- loop
- drop
- launcher
- launch
- air movement
- landing
- new record
- upgrade purchase
- offline rewards

Rarity should influence feedback intensity.

Common pieces:
light feedback

Legendary:
stronger

Mythic / Secret:
dramatic

Do not make every action scream at the player.

==================================================
34. MODELING / ASSET RULES
==================================================

Use the connected design/model plugin for:

- final track pieces
- carts
- buildings
- hub structures
- decorative props
- houses
- world portal
- landmarks
- signs

Model style:

- low-poly
- stylized
- clean
- colorful
- slightly exaggerated
- strong silhouette
- optimized

Ensure:
- correct pivot
- correct orientation
- sensible scale
- optimized collision
- consistent modular sockets

==================================================
35. TRACK VISUAL LANGUAGE
==================================================

COMMON

Simple materials.

UNCOMMON

Small accent color.

RARE

More distinctive shape and trim.

EPIC

Bolder geometry / glow.

LEGENDARY

Gold accents and restrained VFX.

MYTHIC

Strong rainbow/energy identity.

SECRET

Void/cosmic/highly distinctive identity.

Rare pieces should stand out from a distance.

==================================================
36. DATA SAVING
==================================================

Save compact data.

Save:

- Currency
- Upgrade Levels
- Ramp Piece Sequence
- Piece Mutations
- World Progress
- Best Distance
- Prestige Progress later
- Last Logout Timestamp
- Relevant Offline Growth values

Do NOT save Roblox Instances.

Save track piece IDs and essential state.

Reconstruct physical ramp models when loading.

Use safe DataStore patterns including:

- UpdateAsync where appropriate
- pcall
- failure handling
- write throttling
- sensible autosave
- BindToClose handling

==================================================
37. SECURITY
==================================================

Server controls:

- track generation
- RNG
- rarity
- mutations
- money
- upgrade validation
- offline progression
- world unlocks
- launch reward calculation
- distance validation where practical

Never trust client-provided money or reward values.

Client handles:

- UI
- camera
- cosmetic feedback
- local visual responsiveness

Validate RemoteEvents.

Add rate limiting.

Avoid obvious exploit vectors.

==================================================
38. PERFORMANCE
==================================================

Long ramps can become expensive.

Plan for this from the start.

Do NOT render thousands of full-detail sections blindly.

Potential strategies:

- StreamingEnabled
- distance-based rendering
- simplifying distant sections
- hiding non-nearby player ramps
- lightweight meshes
- object pooling
- reduced particles at distance
- LOD-style replacements
- grouping distant basic segments

For MVP:
cap ramp length to a reasonable test size.

Use detailed environment models near:

- hub
- ramp starts
- active gameplay

Use simpler distant geometry.

Target mobile performance.

==================================================
39. ROBLOX PROJECT STRUCTURE
==================================================

Use clean modular Luau.

Suggested structure:

ReplicatedStorage
    Shared
        Config
            GameConfig
            RarityConfig
            EconomyConfig
            OfflineConfig
            UIConfig
        TrackDefinitions
        MutationDefinitions
        UpgradeDefinitions
        WorldDefinitions
    Remotes
    Assets

ServerScriptService
    Services
        PlayerDataService
        PlayerPlotService
        RampService
        RampGenerationService
        OfflineGrowthService
        RideService
        LaunchService
        EconomyService
        UpgradeService
        EventService
        WorldService
        LeaderboardService

StarterPlayer
    StarterPlayerScripts
        Controllers
            RideController
            CameraController
            EffectsController
            UIController
            NotificationController

StarterGui
    MainUI

ServerStorage
    TrackModels
    CartModels
    WorldAssets

Workspace
    Map
    CentralHub
    PlayerPlots
    LaunchArea
    ActiveCarts
    DistanceLandmarks

Improve this structure if there is a concrete technical reason.

==================================================
40. CONFIGURATION-FIRST DESIGN
==================================================

Keep important balance values centralized.

This includes:

- rarity odds
- mutation odds
- generation time
- Luck formula
- upgrade costs
- starting speed
- speed-per-section
- special boost values
- reward formula
- offline cap
- world requirements
- event multipliers
- prestige requirements

Do not bury important numbers throughout scripts.

==================================================
41. MVP SCOPE
==================================================

The MVP should include:

- one polished starter world
- central hub
- approximately 6 player ramp lanes
- personal player plots
- modular track-generation system
- approximately 10 track pieces
- Common through Legendary initially
- Luck
- online ramp growth
- offline growth
- cart ride
- +1 current-run Speed
- special boost pieces
- controlled launch
- distance tracking
- currency
- four upgrades
- DataStore saving
- clean responsive HUD
- basic sounds/effects
- social visibility between ramps

Do NOT build every possible system before determining if the core loop feels satisfying.

==================================================
42. MVP SUCCESS CRITERIA
==================================================

The MVP is successful when:

A player joins.

They spawn in a coherent environment.

They immediately recognize their ramp.

Their ramp contains valid modular pieces.

A new piece generates.

They see the rarity.

They enter their cart.

The ride starts reliably.

Their SPEED rises.

Special pieces visibly affect the ride.

The cart reaches the end.

They launch.

DISTANCE updates live.

They land.

The game calculates a reward.

They receive money.

They purchase Luck or another upgrade.

The next generated piece can improve.

They leave.

They return.

Offline growth correctly generates new pieces.

They want to immediately ride again to beat their distance.

==================================================
43. DEVELOPMENT PHASE 1 — FOUNDATION
==================================================

Inspect the current workspace/repository.

If it contains old Stack Everything work and this is a separate project, do not mix architectures accidentally.

Create:

- core architecture
- configuration modules
- player data model
- plot system
- starter-world blockout
- central hub blockout
- ramp lane layout

Make the blockout functional before final art.

==================================================
44. DEVELOPMENT PHASE 2 — TRACK GENERATION
==================================================

Create:

- standardized track piece format
- entry/exit sockets
- first placeholder pieces
- piece registry
- rarity rolls
- Luck modification
- deterministic placement
- geometry validation
- ramp reconstruction

Verify ramps generate correctly.

==================================================
45. DEVELOPMENT PHASE 3 — RIDE
==================================================

Implement:

- cart spawn
- enter cart
- controlled movement
- track traversal
- +1 Speed system
- special boosts
- curves
- slopes
- drops
- launch transition
- live distance
- landing
- quick return

The critical loop is:

RIDE
→
SPEED
→
LAUNCH
→
DISTANCE

Do not move on until this works reliably.

==================================================
46. DEVELOPMENT PHASE 4 — PROGRESSION
==================================================

Add:

- money rewards
- upgrade system
- Luck
- Growth Speed
- Base Speed
- Offline Time
- rarity feedback

Balance early progression so the player gets upgrades quickly.

==================================================
47. DEVELOPMENT PHASE 5 — SAVING / OFFLINE
==================================================

Implement:

- DataStore
- ramp persistence
- upgrade persistence
- best distance
- logout timestamp
- offline growth
- reconnect safety
- duplicate prevention

Test:

leave
rejoin
server shutdown
reset
disconnect

==================================================
48. DEVELOPMENT PHASE 6 — UI
==================================================

Use Figma.

Design the full UI system.

Then implement it in Roblox.

Test:

- desktop
- small laptop
- tablet
- phone

No overlaps.

Keep center-screen gameplay visible.

==================================================
49. DEVELOPMENT PHASE 7 — FINAL ART
==================================================

Use the design/modeling plugin.

Replace placeholders with:

- final track assets
- hub structures
- houses
- carts
- signs
- environment props
- distance landmarks

Refine:

- lighting
- materials
- environment density
- silhouette
- aerial readability

==================================================
50. DEVELOPMENT PHASE 8 — RNG EXPANSION
==================================================

Add:

- Mythic
- Secret
- mutations
- rare server announcements
- more special track pieces

Do not destroy balance.

==================================================
51. DEVELOPMENT PHASE 9 — EVENTS
==================================================

Add simple events:

- 10x Luck
- Double Growth
- Golden Rush
- Mutation Storm
- Secret Surge

Test that events cleanly start and stop.

==================================================
52. DEVELOPMENT PHASE 10 — POLISH
==================================================

Refine:

- VFX
- SFX
- camera
- speed feel
- launch feel
- landing
- notifications
- cart animation
- rare-piece reveals
- mobile responsiveness
- performance
- collision issues

==================================================
53. POST-MVP — WORLD PROGRESSION
==================================================

Only once starter gameplay feels good:

add future worlds.

Do not merely recolor the same world.

Each should have:

- distinct map
- distinct environment
- new track pieces
- new Secrets
- stronger reward scaling
- different landmarks

==================================================
54. POST-MVP — PRESTIGE
==================================================

Add REBUILD RAMP.

Reset selected progression for permanent bonuses.

Tune it so prestige:
- feels meaningful
- speeds future runs
- does not invalidate the early game

==================================================
55. POST-MVP — DAILY / RETENTION
==================================================

Possible additions:

- daily reward
- streak
- daily Luck
- limited mutations
- rotating Secret piece
- weekend event
- playtime reward

Keep it clean.

==================================================
56. POST-MVP — MONETIZATION
==================================================

Do not implement until the game is fun for free.

Potential products/gamepasses:

- 2x Growth
- 2x Currency
- Luck Boost
- Extra Offline Time
- VIP Cart
- Cart Skins
- Track Skins
- Trails
- Cosmetic Effects

Do not sell direct guaranteed access to ultra-rare RNG items.

Do not make normal progression dependent on purchases.

==================================================
57. ANALYTICS / BALANCE
==================================================

Structure the game so useful gameplay metrics can later be monitored.

Important metrics:

- first ride completion
- first upgrade time
- rides per session
- session length
- first Rare roll time
- first Legendary roll time
- average ramp length
- average launch distance
- offline return behavior
- world unlock time
- prestige timing later

Do not let analytics delay development.

==================================================
58. RELEASE POLISH
==================================================

After systems are stable:

- final logo
- game icon
- thumbnails
- loading screen
- world lighting
- spawn polish
- onboarding polish
- low-end device testing
- multiplayer testing
- remove debug assets
- remove placeholder assets
- remove debug UI
- clean old code
- clean unused files

Use Figma and design tools for release visuals where appropriate.

==================================================
59. QA / EDGE CASES
==================================================

Test:

- two players joining simultaneously
- plot allocation
- player leaving
- plot cleanup
- reconnecting
- player dying during ride
- resetting during ride
- falling off track
- malformed track
- loop transitions
- extreme speed
- very long ramp
- rare piece generation
- mutation generation
- event start/end
- DataStore failure
- offline timestamp issues
- multiple players' ramps near each other
- mobile UI
- low FPS
- latency
- launch distance abuse

Fix obvious problems before continuing.

==================================================
60. VISUAL REFERENCE USAGE
==================================================

Use the attached concept images to understand the intended direction.

The images show:

- compact central hub behind ramps
- visible neighboring player lanes
- a launch landscape with real distance landmarks
- increasingly ridiculous rare tracks
- clean UI
- modular track art
- rarity colors
- mutations

Do NOT blindly copy every visual detail.

Use them as an art-direction target.

The final game should feel coherent and intentionally designed.

==================================================
61. HOW YOU SHOULD WORK
==================================================

Do not reply with only a giant theoretical plan.

Actively perform the work.

For each major phase:

1. inspect existing state
2. briefly state what you are about to change
3. implement
4. review code
5. test what is available
6. fix issues
7. continue

Do not repeatedly stop for confirmation unless:

- a destructive action is required
- access/authentication is required
- an irreversible choice is required
- there is a genuine technical blocker

Otherwise make a reasonable choice and continue.

==================================================
62. FIRST TASK
==================================================

Begin now.

First:

1. inspect the workspace/repository
2. identify anything that should be reused
3. propose/finalize the architecture
4. create the project structure
5. create configuration modules
6. create the player plot system
7. create the starter-world blockout
8. create the central hub blockout
9. create the ramp-lane layout
10. create the standardized modular track format
11. create the first placeholder track pieces
12. implement basic procedural ramp generation

The first milestone is:

A player can join a coherent starter world, receive a personal ramp lane, see neighboring lanes, and have a valid modular ramp generated that is structurally ready for RNG, Luck, offline growth, riding, and launching.

Once that milestone works correctly, continue through the phases in order.

Do NOT stop after merely creating the folder structure.

Do NOT spend excessive time polishing final art before the core gameplay functions.

Do NOT skip testing.

Build the game.
