# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> A Project Zomboid mod that brings the world's barrels to life — giving them randomized contents, persistent state, and interactive gameplay for both singleplayer and multiplayer.

---

## Why was it created?

Project Zomboid's world is packed with industrial and military barrels, but they've always been nothing more than static decorations. You could look at them, walk past them, but never interact with them in any meaningful way.

**Barrels Expanded** was created to fix that. The idea is simple: those barrels should feel like part of the world. Maybe one is full of gasoline left behind by a factory worker. Maybe another holds rainwater collected in an old military camp. You won't know until you crack it open.

The goal is to add depth and unpredictability to exploration without overhauling the game — just small, immersive interactions that make the world feel more alive.

---

## What does it do?

The mod adds interactive behavior to barrels that already exist in the game world (vanilla tiles). When you approach a barrel and interact with it for the first time, you pry it open using a tool — and discover what's inside.

Contents are **randomly generated** at the moment of opening:
- The liquid type (Fuel or Water)
- The amount stored (between 1 and 160 units)

Once opened, the barrel's state is **permanently saved** with the world, so the contents persist across sessions and are shared between all players in multiplayer.

---

## How does it work?

The mod follows a clean **client–server architecture**:

1. **Detection:** When you right-click on a supported barrel tile in the world, the context menu detects it and shows a *"Barrel"* submenu.
2. **Tool check:** Before you can open it, the game checks whether you're carrying at least one of the required tools.
3. **Request:** When you confirm the action, your client sends a network command to the server.
4. **Generation:** The server randomly generates the barrel's liquid type and fill level, then stores the result in the object's `modData`.
5. **Sync:** The server transmits the data back to all clients via `transmitModData()`, keeping every player's view consistent.
6. **Persistence:** The generated data is tied to the barrel's world position and object index, so it survives world saves and server restarts.

On the UI side, a rich **tooltip** is attached to the context menu option showing the barrel's liquid type and current fill level once it has been opened.

---

## Current Features

| Feature | Details |
|---|---|
| **Singleplayer & Multiplayer support** | Fully compatible with both SP and MP |
| **World barrel interaction** | Interact with vanilla barrel tiles found in industrial and military locations |
| **Randomized contents** | Liquid type and amount are randomly assigned on first open |
| **Liquid types** | Fuel and Water |
| **Barrel capacity** | 160 units, with a random fill (1–160) |
| **Required tools** | Any one of: Crowbar, Forged Crowbar, Screwdriver, Pipe Wrench, or Sheet Metal Snips |
| **Rich tooltips** | Shows liquid type and amount/capacity after opening |
| **Persistent state** | Barrel contents are saved with the world and shared between all players |
| **Supported barrel tiles** | Industrial barrels, military camp barrels, and crafted barrels |

---

## Planned Features

- [ ] **Remove Cover action** — Physically remove the barrel lid as a separate step before accessing contents
- [ ] **Transfer liquid** — Pour the barrel's contents into cans, bottles, or other containers
- [ ] **Fill barrels** — Fill an empty barrel with liquid from containers or other sources
- [ ] **More liquid types** — Bleach, alcohol, oil, and other liquids that make sense in the game world
- [ ] **Barrel condition** — Barrels can be rusty or damaged, affecting the quality of their contents
- [ ] **Crafted barrels** — Place and configure your own barrels in the world
- [ ] **Expanded tool list** — Additional tools that can be used to open barrels

---

## Compatibility

- **Game version:** Build 42
- **Multiplayer:** ✅ Fully supported
- **Singleplayer:** ✅ Fully supported
- **Server-side only:** ❌ Not supported (client mod required)

---

## Installation

1. Subscribe to the mod on the Steam Workshop.
2. Enable it from the **Mods** menu in the main menu or when creating a new game.
3. No additional configuration needed.

---

*[Español 🇪🇸](README_ES.md)*
