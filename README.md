# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> A Project Zomboid Build 42 mod that turns world barrels into useful survival resources with randomized contents, persistent state, and interactive gameplay for singleplayer and multiplayer.

---

## Why was it created?

Project Zomboid's world is packed with industrial and military barrels, but most of them are just scenery. You can walk past them, build around them, or ignore them, but they rarely matter.

**Barrels Expanded** changes that. Barrels can become emergency water, fuel reserves, cleaning supplies, or empty containers waiting to be used at your base. You do not know what is inside until you open one.

The goal is to make exploration more rewarding without turning the game into something else.

---

## What does it do?

The mod adds interactive behavior to existing vanilla world barrels. You can:

- Open and inspect barrels.
- Drink from water barrels when the liquid is drinkable.
- Wash yourself, clothing, and washable items with barrel water.
- Pour compatible liquids into barrels.
- Fill compatible containers from barrels.
- Empty barrels progressively when you want to clean them out or change their contents.
- Pick up, move, and place opened barrels while preserving their contents and weight.

Barrel contents are revealed the first time a barrel is opened:

- Liquid type: Water, Tainted Water, Gasoline, Bleach, or Empty.
- Amount: between 1 and 160 units when liquid is present.

Once generated, barrel state is saved in the world and shared in multiplayer.

---

## Existing Features

1. **Open barrel** with one required tool: Crowbar, Forged Crowbar, Screwdriver, Pipe Wrench, or Sheet Metal Snips.
2. **Inspect barrel info** through the Barrel context menu: liquid type, fill level, requirements, item icons, and disabled reasons.
3. **Drink from barrel** when it contains Water or Tainted Water.
4. **Wash from barrel**:
   - Wash your character.
   - Wash clothing and washable inventory items.
   - Clean compatible bandage-like items when the water is safe.
   - Soap is optional, but affects wash speed/cleaning behavior.
5. **Pour into barrel** from compatible inventory containers, requiring a Funnel.
6. **Fill containers from barrel** using compatible inventory containers, requiring a Rubber Hose.
7. **Fill all / grouped fill menu** with vanilla-style container grouping.
8. **Progressive emptying** that drains liquid during the timed action; interrupted actions keep the amount already drained.
9. **Randomized first-open content** based on barrel tile category.
10. **Persistent barrel state** that survives saves, reloads, pickup/place, and server restarts.
11. **Server-safe multiplayer behavior** with protection against overlapping use of the same barrel.
12. **Dynamic barrel weight** based on liquid type and amount.
13. **Singleplayer and multiplayer support**.
14. **Optional mod compatibility** for DamnLib/USMIL military gas and water cans in barrel liquid transfers.
15. **Current translations**: English, Spanish, and Argentinian Spanish.

### Gameplay Data

| Category | Current State |
|---|---|
| Liquid types | Water, Tainted Water, Gasoline, Bleach, Empty |
| Barrel capacity | 160 units |
| Drink amount | 0.12 units per drink action |
| Wash unit cost | 1 unit per washed body/item segment |
| Supported barrel tiles | Industrial, military, and crafted barrel tiles |
| Transfer tools | Funnel for pouring in, Rubber Hose for filling containers |

---

## Planned Features

These are ideas for future versions, not current features:

- **Fuel logistics**: refuel generators or vehicles from gasoline barrels.
- **Barrel-to-barrel transfer**: organize supplies between base storage barrels.
- **Barrel labels or ownership markers**: easier multiplayer base organization.
- **Sandbox options**: tune rarity, capacity, spawn profiles, tool requirements, and behavior.
- **Barrel condition system**: rust, damage, leaks, contamination, or reliability risks.
- **Water treatment interactions**: gameplay steps for making tainted water safer.

---

## Compatibility

- **Game version:** Project Zomboid Build 42
- **Multiplayer:** Supported
- **Singleplayer:** Supported
- **Server-side only:** Not supported; the mod must be enabled on clients too
- **Safe install:** Designed to work with ongoing saves; always back up saves before adding or removing mods

---

## Translations

Current translations:

- English
- Spanish
- Argentinian Spanish

Community translation help is welcome. If you want to help translate Barrels Expanded into another language or improve an existing translation, contributions and suggestions are appreciated.

---

## Installation

1. Subscribe to the mod on Steam Workshop.
2. Enable it from the **Mods** menu in the main menu or when creating a new game.
3. No additional configuration is required.

---

*[Español](README_ES.md)*
