# Balance report

Generated with the balance simulator, which plays a virtual player using the *real* shared systems
(RampGenerator, RideSim, Economy):

```bash
lune run tests/tools/simulate.luau <minutes> <seed>
```

Simulated policy: ride back-to-back (ride time + 5 s to board) and buy the cheapest affordable
upgrade after every ride. Real players are slower (exploring, reading menus) and less optimal, so
treat these numbers as an upper bound on pace.

## Seed 1 (60 minutes)

```
Simulated 60 minutes (seed 1)

  0.3 min | rides   1 | pieces  4 | speed   24 | best    249 | cash       27 | luck 0 growth 0 speed 1 offline 0
  5.2 min | rides  17 | pieces 24 | speed   89 | best    812 | cash      228 | luck 5 growth 6 speed 7 offline 1
 10.0 min | rides  31 | pieces 42 | speed  163 | best  1,400 | cash      471 | luck 7 growth 8 speed 10 offline 2
 15.0 min | rides  46 | pieces 41 | speed  201 | best  1,691 | cash    1,606 | luck 8 growth 10 speed 12 offline 2
 20.1 min | rides  62 | pieces 41 | speed  299 | best  2,417 | cash    1,212 | luck 10 growth 11 speed 14 offline 3
 25.2 min | rides  78 | pieces 40 | speed  323 | best  2,591 | cash      656 | luck 11 growth 12 speed 15 offline 3
 30.0 min | rides  93 | pieces 40 | speed  329 | best  2,635 | cash    1,773 | luck 11 growth 12 speed 16 offline 4
 35.2 min | rides 109 | pieces 40 | speed  336 | best  2,685 | cash    2,173 | luck 11 growth 13 speed 17 offline 4
 40.1 min | rides 124 | pieces 40 | speed  336 | best  2,685 | cash   10,398 | luck 12 growth 13 speed 17 offline 4
 45.2 min | rides 140 | pieces 41 | speed  354 | best  2,814 | cash   12,978 | luck 12 growth 14 speed 18 offline 4
 50.1 min | rides 155 | pieces 39 | speed  407 | best  3,191 | cash   18,335 | luck 13 growth 14 speed 19 offline 4
 55.1 min | rides 170 | pieces 39 | speed  412 | best  3,226 | cash   22,336 | luck 13 growth 15 speed 19 offline 5
 60.1 min | rides 185 | pieces 39 | speed  416 | best  3,254 | cash   15,573 | luck 14 growth 16 speed 20 offline 5

Milestones:
    16.6s  (  0.3 min)  First upgrade
    16.6s  (  0.3 min)  First Common
    49.7s  (  0.8 min)  First mutation
    49.7s  (  0.8 min)  First Uncommon
   102.9s  (  1.7 min)  First Rare
   139.1s  (  2.3 min)  Reached Creek
   376.6s  (  6.3 min)  First Epic
   396.7s  (  6.6 min)  Reached Road
   560.6s  (  9.3 min)  Ramp full
  1304.4s  ( 21.7 min)  Reached Town
  1819.9s  ( 30.3 min)  First Legendary
  2968.5s  ( 49.5 min)  First Mythic
  3525.1s  ( 58.8 min)  First Secret

Final: 39 pieces, best 3,254 studs, 185 rides
Lane cap 50 pieces
```

## Seed 2 (60 minutes)

```
Simulated 60 minutes (seed 2)

  0.3 min | rides   1 | pieces  4 | speed   24 | best    249 | cash       27 | luck 0 growth 0 speed 1 offline 0
  5.2 min | rides  17 | pieces 23 | speed   87 | best    795 | cash      100 | luck 4 growth 5 speed 7 offline 1
 10.2 min | rides  32 | pieces 42 | speed  178 | best  1,516 | cash      150 | luck 6 growth 8 speed 10 offline 2
 15.1 min | rides  47 | pieces 39 | speed  250 | best  2,058 | cash      448 | luck 9 growth 10 speed 13 offline 3
 20.1 min | rides  63 | pieces 38 | speed  349 | best  2,800 | cash    2,006 | luck 11 growth 12 speed 16 offline 3
 25.2 min | rides  79 | pieces 38 | speed  375 | best  2,964 | cash      976 | luck 12 growth 13 speed 17 offline 4
 30.0 min | rides  94 | pieces 38 | speed  462 | best  3,576 | cash    6,508 | luck 13 growth 14 speed 19 offline 4
 35.1 min | rides 110 | pieces 37 | speed  546 | best  4,157 | cash   17,719 | luck 14 growth 15 speed 19 offline 5
 40.0 min | rides 125 | pieces 39 | speed  609 | best  4,586 | cash   35,781 | luck 14 growth 16 speed 20 offline 5
 45.2 min | rides 141 | pieces 40 | speed  690 | best  5,132 | cash    2,181 | luck 15 growth 17 speed 21 offline 5
 50.1 min | rides 156 | pieces 41 | speed  745 | best  5,498 | cash   51,697 | luck 15 growth 17 speed 22 offline 5
 55.2 min | rides 171 | pieces 41 | speed  755 | best  5,565 | cash   32,017 | luck 16 growth 18 speed 22 offline 5
 60.2 min | rides 186 | pieces 41 | speed  759 | best  5,591 | cash   77,753 | luck 16 growth 18 speed 23 offline 5

Milestones:
    16.6s  (  0.3 min)  First upgrade
    16.6s  (  0.3 min)  First Common
    49.6s  (  0.8 min)  First Uncommon
   138.0s  (  2.3 min)  Reached Creek
   174.8s  (  2.9 min)  First mutation
   331.5s  (  5.5 min)  First Rare
   372.4s  (  6.2 min)  First Epic
   412.7s  (  6.9 min)  Reached Road
   569.4s  (  9.5 min)  Ramp full
   826.6s  ( 13.8 min)  First Legendary
  1074.1s  ( 17.9 min)  Reached Town
  1532.7s  ( 25.5 min)  First Secret
  1839.3s  ( 30.7 min)  First Mythic
  2498.3s  ( 41.6 min)  Reached Canyon

Final: 41 pieces, best 5,591 studs, 186 rides
Lane cap 50 pieces
```

## Reading the numbers

* **First minute works.** The first upgrade lands at ~17 s (first ride ≈ 249 studs → $62, the
  cheapest upgrade is $35), and the fast-forwarded next piece arrives ~5 s later.
* **RNG cadence.** Rare at 2–6 min, Epic at ~6 min, Legendary at 14–30 min. Mythic and Secret are
  luck-dependent long-tail moments (seed 2 got a Secret at 25 min; most players will not).
* **Landmarks.** Creek at ~2 min, Road at ~7 min, Town at ~20 min, Canyon around 40+ min with good
  rolls. The Mountain (10,000) is aspirational in the starter world, by design.
* **The lane fills at ~9.5 min.** After that, growth upgrades pieces instead of adding length, and
  progress is driven by rarity, Base Speed and launchers. This is the natural point for post-MVP
  systems (Rebuild Ramp prestige, the City world).

## Tuning knobs

| Goal | Change |
|---|---|
| Slower / longer visible growth | raise `EconomyConfig.Growth.BaseInterval`, or lengthen lanes (`GameConfig.Lanes.LipExitRadius`) |
| Bigger ramps | `GameConfig.Track.MaxPieces` plus lane depth |
| More frequent rare moments | `RarityConfig.Rarities.*.Weight` or `LuckExponentPerTier` |
| Faster distance growth | `RideConfig.Launch.DistanceExponent` / `DistanceScale` |
| More cash per ride | `EconomyConfig.Reward.RewardPerStud` |
| Smoother long-term upgrades | lower `CostGrowth` in `UpgradeDefinitions` |
