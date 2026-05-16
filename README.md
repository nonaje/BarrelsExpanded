# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> A Project Zomboid mod that brings the world's barrels to life, giving them randomized contents, persistent state, and interactive gameplay for both singleplayer and multiplayer.

---

## Why was it created?

Project Zomboid's world is packed with industrial and military barrels, but they are usually static decorations. You could see them and walk past them, but not interact with them in a meaningful way.

**Barrels Expanded** was created to fix that. The idea is simple: barrels should feel like part of the world. Maybe one holds gasoline left behind by a worker. Maybe another contains rainwater collected in an old military camp. You do not know until you open it.

The goal is to add depth and unpredictability to exploration without overhauling the game.

---

## What does it do?

The mod adds interactive behavior to existing vanilla world barrels. You can:

- Open and inspect barrels.
- Drink from them (when the liquid is drinkable).
- Wash yourself or clothing with barrel water.
- Pour liquid into barrels.
- Extract liquid from barrels.
- Empty barrels.

Barrel contents are generated the first time a barrel is opened:

- Liquid type: Water, Tainted Water, Gasoline, or Bleach.
- Amount: between 1 and 160 units.

Once generated, state is saved in world data and shared in multiplayer.

---

## How does it work?

The mod follows a client-server architecture:

1. **Detection:** The context menu detects supported barrel tiles and shows a Barrel submenu.
2. **Request:** The client sends the requested action to the server.
3. **Validation:** The server validates range, tools, item identity, and liquid compatibility.
4. **Mutation:** The server applies real state changes (drink/wash/transfer/empty).
5. **Sync:** The server updates clients through `transmitModData()` and network messages.
6. **Persistence:** Barrel data survives saves and server restarts.

---

## Existing Features

1. **Open barrel** with one required tool: Crowbar, Forged Crowbar, Screwdriver, Pipe Wrench, or Sheet Metal Snips.
2. **Inspect barrel info** via context tooltips (liquid type, fill level, requirements, disabled reasons).
3. **Drink from barrel** (Water and Tainted Water).
4. **Wash from barrel**:
   - Wash yourself.
   - Wash clothing and washable items.
   - Soap is optional, but changes wash speed.
5. **Pour into barrel** from compatible inventory containers (requires Funnel).
6. **Extract from barrel** into compatible inventory containers (requires Rubber Hose).
7. **Empty barrel** completely.
8. **Randomized first-open content** based on barrel tile category.
9. **Persistent state** stored in `modData`.
10. **Server-authoritative multiplayer** with transfer locks to avoid overlap on the same barrel.
11. **Dynamic barrel weight** based on liquid type and amount.
12. **Singleplayer and multiplayer support**.

### Gameplay Data

| Category | Current State |
|---|---|
| Liquid types | Water, Tainted Water, Gasoline, Bleach |
| Barrel capacity | 160 units |
| Drink amount | 0.12 units per drink action |
| Wash unit cost | 1 unit per washed body/item segment |
| Supported barrel tiles | Industrial, military, and crafted barrel tiles |

---

## Planned Features

- [ ] **Separate lid workflow**: staged interaction (remove lid vs open/inspect).
- [ ] **Barrel condition system**: rust/damage affecting reliability and quality.
- [ ] **Sandbox configuration options**: spawn profiles, capacity rules, behavior tuning.
- [ ] **Extended liquid ecosystem**: more liquid types with balanced compatibility.

---

## Future Ideas

- Refuel generators from gasoline barrels.
- Refuel vehicles from gasoline barrels.
- Transfer liquid between barrels.
- Drain vehicle fuel into barrels.
- Add barrel labels/ownership markers for multiplayer organization.
- Add water treatment interactions (for example, filtering tainted water through gameplay steps).

---

## Compatibility

- **Game version:** Build 42
- **Multiplayer:** Fully supported
- **Singleplayer:** Fully supported
- **Server-side only:** Not supported (client mod required)

---

## Installation

1. Subscribe to the mod on Steam Workshop.
2. Enable it from the **Mods** menu in the main menu or when creating a new game.
3. No additional configuration is required.

---

*[Español](README_ES.md)*
