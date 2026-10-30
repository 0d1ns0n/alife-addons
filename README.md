<!-- ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ -->

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0f2027,50:203a43,100:2c5364&height=210&section=header&text=A-Life%20Add-ons&fontSize=72&fontColor=ffffff&fontAlignY=36&desc=Build%20a%20living%20settlement%20in%20Project%20Zomboid&descSize=20&descAlignY=60&animation=fadeIn" width="100%" alt="A-Life Add-ons"/>

<a href="https://readme-typing-svg.demolab.com">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=22&duration=3400&pause=900&color=4CAF50&center=true&vCenter=true&width=820&lines=Mark+the+land.+Call+the+survivors.;They+clear%2C+build%2C+farm+and+defend+%E2%80%94+on+their+own.;Camp+%E2%86%92+Outpost+%E2%86%92+Village+%E2%86%92+Town+%E2%86%92+City." alt="tagline"/>
</a>

<br/><br/>

<img src="https://img.shields.io/badge/Project%20Zomboid-Build%2042.21-8bc34a?style=for-the-badge&logo=steam&logoColor=white" alt="PZ B42.21"/>
<img src="https://img.shields.io/badge/ALifeCamp-0.6-2e7d32?style=for-the-badge" alt="ALifeCamp 0.6"/>
<img src="https://img.shields.io/badge/ALifeRU-0.2-2e7d32?style=for-the-badge" alt="ALifeRU 0.2"/>
<img src="https://img.shields.io/badge/requires-Project%20A--Life%20NPCs-ff7043?style=for-the-badge" alt="requires A-Life"/>
<br/>
<img src="https://img.shields.io/badge/built%20with-Lua-000080?style=flat-square&logo=lua&logoColor=white" alt="Lua"/>
<img src="https://img.shields.io/badge/status-active%20%7C%20always%20improving-blue?style=flat-square" alt="status"/>
<img src="https://img.shields.io/badge/tested-in--game-brightgreen?style=flat-square" alt="tested in-game"/>
<br/>
<img src="https://img.shields.io/badge/languages-EN%20%C2%B7%20RU%20%C2%B7%20UK%20%C2%B7%20DE%20%C2%B7%20IT-9c27b0?style=flat-square" alt="languages"/>

</div>

<br/>

<div align="center">
  <img src="docs/img/hero-watchtowers.jpg" width="92%" alt="A settlement built by ALifeCamp: concrete perimeter wall, twin watchtowers, inner courtyard and gardens"/>
  <br/>
  <sub><i>A settlement raised by the settlers themselves — perimeter wall, twin watchtowers, courtyard and gardens. Shown in the author's game running the 3D <b>Viewpoint</b> mod with shaders; base Project Zomboid is isometric (see the night shot below).</i></sub>
</div>

<br/>

## ✦ The idea

> **Project Zomboid is a world you survive _alone_. [Project A-Life](https://steamcommunity.com/workshop/) fills it with living NPCs. These add-ons let you _belong_ to it.**

Mark out land with four flags and invite the wanderers you meet. From there they do the rest — clear the plot, raise a walled perimeter with working gates, build checkpoints, houses, farms, watchtowers, a garage and a motor pool, recycle junk, level up their skills, and hold the line when raiders come.

There is **no final version**. This is a long-running project that keeps converging toward a moving **reference standard**: the best layout, the smartest behaviour, the most alive world. When the standard improves, existing settlements **auto-rebuild toward it on reload** — tearing down the old and raising the new — so you never have to regenerate anything by hand.

<br/>

## ✦ What's inside

<table>
<tr>
<td width="50%" valign="top">

### 🏰 ALifeCamp
**Settlements that build themselves.**
Flag off any plot, invite A-Life NPCs, and watch a real community grow: storage, a walled perimeter with gates, defended checkpoints, houses, farms, watchtowers, a garage & motor pool. Settlers clear land, recycle, farm, skill up and fight off raids on their own. Grows **camp → city**.

`requires` Project A-Life NPCs

</td>
<td width="50%" valign="top">

### 📻 ALifeRU
**A living, Russian-speaking world.**
Full Russian localization of Project A-Life (speech, radio, UI) plus a pack of **16 world events** — raids, gang wars, bikers, arson, a sheriff response, roadblocks, ambushes, refugees, supply drops, chopper crashes, horde marches, military sweeps.

`requires` Project A-Life NPCs

</td>
</tr>
</table>

<br/>

## ✦ How a settlement builds itself

Every in-game minute the settlement runs one step of a real pipeline:

| Phase | What the settlers do |
|:--|:--|
| 🧹 **Clear** | Fell trees, cut grass, haul junk, remove wrecks & corpses — logs and planks go to storage |
| 📐 **Plan** | Auto-draft and extend a layout: perimeter fence, gates, checkpoints, storage, houses, farms, towers, plaza, streets, lamps, market, wells, gardens, garage, range |
| 🔨 **Build** | Raise it stage-by-stage from real vanilla tiles; speed scales with builders and their skill |
| 📦 **Supply** | Bottomless crates; settlers haul boards, nails, metal, food, water, meds, ammo, seeds |
| ♻️ **Economy** | Saw logs → planks, recycle scrap → cloth/metal, forge nails, harvest crops, scavenge nearby houses |
| 🛡️ **Defend** | Walls, towers, checkpoints, vehicles on posts, armed guards; raids hit the gates |
| 📈 **Grow** | When it's built and peopled, the border pushes outward and the tier climbs |

<br/>

### Settlement tiers

```mermaid
flowchart LR
    A([🏕️ Camp]) --> B([⛺ Outpost]) --> C([🏘️ Village]) --> D([🏙️ Town]) --> E([🌆 City])
    style A fill:#37474f,stroke:#90a4ae,color:#fff
    style B fill:#33691e,stroke:#aed581,color:#fff
    style C fill:#1b5e20,stroke:#81c784,color:#fff
    style D fill:#0d47a1,stroke:#64b5f6,color:#fff
    style E fill:#4a148c,stroke:#ba68c8,color:#fff
```

A settlement is promoted only when **population, size _and_ building count** all cross the next threshold (roughly **5 → 12 → 25 → 50** settlers), and it never gets demoted on a bad week.

<br/>

## ✦ Gallery

<table>
<tr>
<td width="50%"><img src="docs/img/courtyard-garden.jpg" alt="Courtyard with twin watchtowers and garden plots"/><br/><sub>Inner courtyard, twin watchtowers & garden plots</sub></td>
<td width="50%"><img src="docs/img/gate-garden.jpg" alt="Perimeter gate and gardens under a storm sky"/><br/><sub>Perimeter gate and gardens</sub></td>
</tr>
<tr>
<td width="50%"><img src="docs/img/iso-town-night.jpg" alt="Isometric night view — the native Project Zomboid perspective"/><br/><sub>The native isometric view at night</sub></td>
<td width="50%"><img src="docs/img/yard-fences.jpg" alt="Fenced yards and paths inside the settlement"/><br/><sub>Fenced lots and tidy paths between buildings</sub></td>
</tr>
</table>

<br/>

## ✦ Languages

ALifeCamp speaks **English, Русский, Українська, Deutsch and Italiano**. It follows the language you pick in the game's own **Options → Language** automatically — that menu is the one chooser for everything. Prefer a different language just for the mod? Open the camp window (**F6 → Settings**) and click the **Language** line to cycle **Auto → English → Русский → Українська → Deutsch → Italiano**; the choice is remembered and overrides only ALifeCamp. Anything a language is missing falls back to English.

> Translations are community-grade and easy to extend — drop a `Translate/<CODE>/UI.json` next to the others. Corrections welcome via issues.

## ✦ Install & load order

Enable in-game, then **restart** — Project Zomboid reads Lua only at launch.

```
1. Project A-Life NPCs
2. ALifeRU
3. ALifeCamp
```

Copy the folders from [`mods/`](mods) into `%UserProfile%\Zomboid\mods`, or run:

```bash
python tools/install.py
```

Open the camp window with **F6**: take the four flags, place them at the corners, create the camp, then right-click a friendly A-Life NPC → **Camp → Invite**.

<details>
<summary><b>More details & docs</b></summary>

- 📖 [ALifeCamp guide](docs/ALifeCamp.md) — every phase, window tabs, gates, vehicles, skills, options
- 📻 [ALifeRU guide](docs/ALifeRU.md) · [full event list](docs/ALifeRU-events.md)
- 🛠️ [Development](docs/DEVELOPMENT.md) — how the code is laid out, the engine-model tests, the sync workflow
- 🤝 [Sharing](docs/SHARING.md) — collaborators, friend archives, Steam Workshop

</details>

<br/>

## ✦ Roadmap

- [x] Self-building settlements with clear → plan → build → defend loop
- [x] Walled perimeter, wide vehicle gates, defended checkpoints, watchtowers
- [x] Tier model (camp → city) with hysteresis
- [x] House adoption, farms & gardens, recycling economy, power grid
- [x] Auto-converge old settlements to the latest design standard on reload
- [ ] Richer combat-ready checkpoints (post-apocalyptic blockpost designs)
- [ ] Compact camp UI with an overall build % and a tiled project grid
- [ ] More believable construction animations & settler attachment
- [ ] Keep closing the gap to the reference standard, update after update

<br/>

## ✦ Credits & permissions

- Built on top of **Project A-Life NPCs** — these are add-ons that require it. All credit for A-Life goes to its author.
- **ALifeRU** includes Russian translations of Project A-Life's in-game strings, used to localize the mod and credited to the original work. If you are the A-Life author and would like a change, please open an issue.
- Developed for Project Zomboid **Build 42.21** by [**0d1ns0n**](https://github.com/0d1ns0n). Screenshots are from the author's own game.

> **License:** personal project — all rights reserved. You're welcome to play with it and open issues; please ask before redistributing, especially the translated strings.

<br/>

<div align="center">
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:2c5364,50:203a43,100:0f2027&height=120&section=footer" width="100%" alt=""/>
</div>
