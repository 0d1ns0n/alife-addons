# A-Life Add-ons for Project Zomboid (Build 42)

Add-ons for [Project A-Life NPCs](https://steamcommunity.com/workshop/) that turn Build 42.21 from a lonely survival sandbox into a **living world you can shape and belong to**. By [0d1ns0n](https://github.com/0d1ns0n).

> Project Zomboid is a world you survive *alone*. Project A-Life fills it with living NPCs. These mods go one step further: let you **recruit those people, build a real community with them, and have the world live around you** — raids, gangs, a sheriff, refugees, supply drops — in your own language.

## The idea / where this is going

There is no "final" version. This is a long-running hobby project that keeps improving toward a moving **reference standard**: the best layout, the best behaviour, the smartest world. The direction:

- **A settlement that builds itself.** You mark out land with four flags and invite wanderers; they clear the plot, raise a walled perimeter with working gates, checkpoints, houses, farms, watchtowers, a garage and a motor pool, recycle junk, level up, and fight off raids — on their own.
- **It grows camp → outpost → village → town → city.** A tier model drives how big and how complex a settlement gets, with hysteresis so a bad week never demotes it.
- **It self-heals toward the latest design.** When the mod improves, existing settlements should **auto-converge** to the new standard on reload — tear down the old, build the new — instead of you regenerating the map by hand.
- **The world lives.** Scripted events (raids, gang wars, bikers, arson, a sheriff response, roadblocks, ambushes, refugees, supply drops, helicopter crashes, horde marches, military sweeps) keep the map moving, and everything — speech, radio, UI — is localized.
- **It stays passable and believable.** Real tile paths connect every building so NPCs don't get stuck; nothing builds on water; zoning keeps a shooting range away from the bedrooms.

## What's inside

| Mod | Version | What it does | Requires |
|---|---|---|---|
| [ALifeCamp](mods/ALifeCamp) | 0.6 | **Settlements.** Flag off land, invite A-Life NPCs, and they clear it and build/run a camp: storage, walled perimeter with gates, checkpoints, houses, farms, watchtowers, garage, motor pool; they recycle, skill up and defend. Grows to a town. | Project A-Life NPCs |
| [ALifeRU](mods/ALifeRU) | 0.2 | **Russian localization of Project A-Life** (speech, radio, UI) + a pack of 16 **living-world events**. | Project A-Life NPCs |

Details: [ALifeCamp](docs/ALifeCamp.md) · [ALifeRU](docs/ALifeRU.md) ([event list](docs/ALifeRU-events.md)).

## Requirements & load order

1. Project A-Life NPCs
2. **ALifeRU**
3. **ALifeCamp**

Build 42.21. Lua is read only at launch, so enable the mods in-game and restart.

## Install

Copy the folders from `mods/` into `%UserProfile%\Zomboid\mods`, or run:

```
python tools/install.py
```

## Development

Mods are edited live in the game folder and mirrored here with a script:

```
python tools/sync_from_game.py     # copy ALifeCamp + ALifeRU from the game into mods/
python tools/tests/run_tests.py    # engine-model tests for the settlement logic
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) and [docs/SHARING.md](docs/SHARING.md).

## Third-party content & license

ALifeRU contains **Russian translations of Project A-Life strings** — ask the A-Life author before publishing these publicly. The repository is **private** for now and no license is granted: all rights reserved by the author. A `LICENSE` must be added before going public.
