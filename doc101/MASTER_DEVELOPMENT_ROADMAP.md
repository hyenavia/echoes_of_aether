# ECHOES OF AETHER
## MASTER DEVELOPMENT ROADMAP

**Project:** Echoes of Aether  
**Genre:** Idle Dungeon RPG / Fantasy Adventure  
**Platform:** Android First, iOS Planned  
**Engine:** Flutter + Flame  
**Architecture:** Modular, Clean Architecture-inspired  
**Visual Style:** 2D Top-down Pixel Art  
**Development Mode:** Offline-first, Single-player  
**Roadmap Version:** 1.0

---

# 1. PROJECT OVERVIEW

Echoes of Aether is a 2D top-down fantasy Idle Dungeon RPG built with Flutter and Flame.

The game features one main character who automatically explores dungeon rooms, fights enemies, uses skills, collects equipment, and progresses through increasingly challenging encounters.

The player does not directly control character movement during combat. Movement, target selection, basic attacks, and skill execution are handled by the game's automated gameplay systems.

The game is designed around these core principles:

1. Fully automatic character movement.
2. Real-time automatic combat.
3. One main character with class specialization.
4. Room-based dungeon progression.
5. Equipment and character progression.
6. Automatic revive with cooldown.
7. Offline-first single-player gameplay.
8. Modular architecture that supports future expansion.

## 1.1 Locked Design Decisions

The following decisions are considered established project requirements.

| Category | Decision |
|---|---|
| Game name | Echoes of Aether |
| Genre | Idle Dungeon RPG |
| Visual | Top-down 2D Pixel Art |
| Movement | Fully automatic |
| Combat | Real-time Auto Combat |
| Character | One main character |
| Class | Class Specialization |
| Dungeon | Room-based |
| Death | Automatic revive with cooldown |
| Game mode | Single-player |
| Network | Offline-first |
| Platform | Android first |
| Engine | Flutter + Flame |

Do not change these decisions without explicit project-owner approval.

---

# 2. TECHNICAL ARCHITECTURE

The project uses a modular architecture with clear separation of responsibilities.

## 2.1 Main Layers

### Presentation
Responsible for:
- Flutter screens.
- HUD.
- Inventory UI.
- Character UI.
- Skill UI.
- Dungeon overlays.

### Application
Responsible for:
- Controllers.
- Providers.
- Use cases.
- Application state.
- Coordination between systems.

### Domain
Responsible for:
- Gameplay entities.
- Character attributes.
- Combat calculations.
- Skill logic.
- Progression.
- Loot logic.
- Dungeon rules.
- Offline simulation.

### Game
Responsible for:
- Flame game instance.
- World rendering.
- Components.
- Sprite animations.
- Camera.
- Tilemap integration.
- Visual effects.

### Data
Responsible for:
- Drift / SQLite.
- JSON configuration.
- Repositories.
- Save/load.
- Database migrations.

## 2.2 Architecture Rules

- Domain must not depend on Flutter or Flame.
- Flame components must not own authoritative gameplay statistics.
- Combat and damage calculations must remain in the domain layer.
- UI must not access the database directly.
- Riverpod must not be updated on every rendering frame.
- Static game configuration should be separated from player progression data.
- Save/load operations must be handled through repositories.
- Gameplay simulation must be independent of rendering frequency.

## 2.3 Simulation

The intended simulation frequency is 20 ticks per second.

Use a fixed simulation timestep of 50 milliseconds.

Rendering and simulation must remain separate.

Do not manually invoke rendering from the simulation system. Let Flame handle rendering through its normal lifecycle.

---

# 3. MILESTONE OVERVIEW

The project is divided into seven main milestones.

| Milestone | Name | Primary Goal |
|---|---|---|
| M1 | Project Foundation | Establish technical foundation |
| M2 | World & Player | Build playable world and automatic movement |
| M3 | Combat System | Implement automatic combat and enemy AI |
| M4 | RPG Progression | Implement character growth and RPG systems |
| M5 | Dungeon System | Implement room-based dungeon progression |
| M6 | Persistence & Offline Progression | Complete saving and offline simulation |
| M7 | Polish & Optimization | Prepare the MVP for release |

A milestone may contain multiple phases and subtasks.

Milestones must be completed based on actual implementation and testing, not merely the presence of files or UI screens.

---

# MILESTONE 1 — PROJECT FOUNDATION

## Objective

Establish the technical foundation of Echoes of Aether.

## Scope

### Project Setup
- Flutter project initialization.
- Flame integration.
- Riverpod integration.
- Drift/SQLite setup.
- Freezed and JSON serialization setup.
- Dependency configuration.

### Architecture
- Establish folder structure.
- Separate domain, application, data, presentation, and game layers.
- Establish repository interfaces.
- Establish error-handling conventions.

### Game Initialization
- Initialize Flame game instance.
- Configure camera.
- Configure game viewport.
- Load initial assets.
- Render an empty test world.

### Configuration
- Establish asset loading conventions.
- Establish JSON configuration loading.
- Establish environment and development configuration.

## Acceptance Criteria

- [ ] Project builds successfully.
- [ ] Dependencies resolve correctly.
- [ ] Application starts.
- [ ] Flame initializes.
- [ ] A basic game world can be rendered.
- [ ] Riverpod works.
- [ ] Database initializes.
- [ ] Domain layer has no Flutter/Flame dependency.
- [ ] Basic tests pass.

## Exit Condition

The project has a stable technical foundation and is ready for gameplay development.

---

# MILESTONE 2 — WORLD & PLAYER

## Objective

Build the game world and establish automatic character movement.

## Scope

### World
- Tilemap integration.
- Ground layer.
- Environment objects.
- Collision layer.
- Navigation grid.

### Player
- Player entity.
- Player component.
- Sprite loading.
- Animation state.
- Position management.
- Direction management.

### Movement
- Automatic movement.
- Navigation target selection.
- A* pathfinding.
- Obstacle avoidance through navigation grid.
- Attack-position navigation foundation.

### Camera
- Camera follow.
- Camera bounds.
- World boundaries.

## Acceptance Criteria

- [ ] Player appears in the world.
- [ ] Player animations work.
- [ ] Player moves automatically.
- [ ] Player follows a navigation path.
- [ ] Player avoids blocked navigation tiles.
- [ ] Camera follows player correctly.
- [ ] Collision works.
- [ ] World and player position remain synchronized.
- [ ] Navigation tests pass.

## Exit Condition

The player can navigate the world automatically without manual joystick input.

---

# MILESTONE 3 — COMBAT SYSTEM

## Objective

Implement the core real-time automatic combat system.

## Scope

### Target Selection
- Enemy detection.
- Target prioritization.
- Target validation.
- Target switching.

Suggested target priority:
1. Enemy currently attacking the player.
2. Nearest valid enemy.
3. Elite enemy when applicable.
4. Lowest HP enemy when configured.

Target priority must remain configurable.

### Basic Combat
- Automatic basic attacks.
- Attack interval.
- Attack range.
- Damage calculation.
- Defense calculation.
- Critical hit.
- HP management.

### Enemy AI
- Idle.
- Detect.
- Chase.
- Attack.
- Return.
- Dead.

### Death & Revive

Current baseline rules:

When player HP reaches zero:
1. Enter Downed state.
2. Stop normal combat actions.
3. Wait 3 seconds.
4. If revive is available, restore 30% max HP.
5. Apply 2 seconds of invulnerability.
6. Start a 90-second revive cooldown.

If the player dies while revive cooldown is active:
- End the dungeon run.
- Return to town.
- Retain equipment.
- Retain confirmed loot.
- Do not count unfinished room completion.

### Combat Feedback
- Damage numbers.
- Hit effects.
- Attack animations.
- Enemy death animations.

## Acceptance Criteria

- [ ] Enemies can detect the player.
- [ ] Enemies can chase the player.
- [ ] Player automatically selects targets.
- [ ] Player automatically attacks.
- [ ] Damage is calculated correctly.
- [ ] Critical hits work.
- [ ] Enemy HP works.
- [ ] Enemy death works.
- [ ] Player death works.
- [ ] Auto revive works.
- [ ] Revive cooldown works.
- [ ] Combat tests pass.

## Exit Condition

A complete basic combat encounter can run automatically without manual combat input.

---

# MILESTONE 4 — RPG PROGRESSION

## Objective

Implement the RPG systems that allow the character to grow stronger over time.

This milestone connects character attributes, skills, specialization, equipment, inventory, loot, and progression.

## Scope

### 4.1 Character Attributes

Implement:
- HP.
- ATK.
- DEF.
- ASPD.
- CRIT Rate.
- CRIT Damage.
- Move Speed.
- Attack Range.
- Skill Haste.

Support derived attributes.

Suggested calculation structure:

Base Attributes
+ Equipment Modifiers
+ Specialization Modifiers
+ Passive Skill Bonuses (scaled by specialization skill affinity)
= Final Attributes

Avoid applying modifiers repeatedly. Implemented via centralized stateless `DerivedStatsCalculator` (`StatBounds` clamping, single rounding on integer stats, `attackRange` override + additive modifier support).

### 4.2 Character Leveling

Implement:
- Character EXP.
- EXP requirements.
- Level-up logic.
- Level-up rewards.
- Attribute progression.
- Maximum level configuration.

EXP sources:
- Normal enemy kills.
- Elite kills.
- Boss kills.
- Dungeon completion.
- Quests when available.

### 4.3 Gold Management

Implement:
- Gold rewards.
- Gold balance.
- Reward validation.
- Gold transaction handling.

### 4.4 Loot System

Implement:
- Loot tables.
- Drop chances.
- Rarity.
- Item generation.
- Enemy loot.
- Elite loot.
- Boss loot.

Rarity:
- Common.
- Uncommon.
- Rare.
- Epic.
- Legendary.

Loot calculations must be deterministic in tests.

### 4.5 Inventory System

Implement:
- Inventory entries.
- Item instances.
- Stackable items where appropriate.
- Item quantity.
- Item capacity if required by the existing design.
- Item acquisition.
- Item removal.
- Inventory validation.

### 4.6 Equipment System

MVP equipment slots:
- Weapon.
- Head.
- Body.
- Accessory.

Implement:
- Equip item.
- Unequip item.
- Equipment validation.
- Attribute modifiers.
- Equipment replacement.
- Equipment persistence.

### 4.7 Skill System

Implement:
- Skill definitions.
- Skill runtime state.
- Skill unlock.
- Skill leveling.
- Skill cooldown.
- Skill target validation.
- Skill range.
- Active skills.
- Passive skills.
- Automatic skill execution.

Initial skill collection:

**Power Strike**
Physical damage skill.

**Aether Burst**
Magical area damage.

**Healing Pulse**
Automatic HP recovery.

**Vitality**
Passive defensive bonus.

**Focus**
Passive offensive or skill effectiveness bonus.

Skill balancing should be data-driven.

### 4.8 Class Specialization

The player has one main character with three specialization options.

**Vanguard**
- Physical combat.
- Durability.
- Melee specialization.

**Arcanist**
- Magical damage.
- Area damage.
- Aether manipulation.

**Ranger**
- Ranged combat.
- Attack speed.
- Precision.

Implement:
- Specialization definitions.
- Specialization selection.
- Specialization bonuses.
- Skill compatibility.
- Starting skills.
- Unlock requirements.
- Persistence.

Do not implement three independent player characters.

### 4.9 Progression Integration

All progression systems must work together via `RewardProcessor`, `EquipmentService`, `DerivedStatsCalculator`, and `PlayerSaveSnapshot`:

Examples:
- Level-up changes character attributes (`ProgressionConfig.statsAt` -> `DerivedStatsCalculator`).
- Equipment modifies final attributes and validates slot/bag capacity (`EquipmentService`).
- Passive skills and active specializations modify final attributes without double stacking.
- Skills use final attributes for combat calculations.
- Loot enters inventory (`Inventory` stacks, `maxStack: 1` quest items, `EquipmentInstance` bag) with duplicate-claim prevention (`RewardProcessor`).
- Equipment changes update combat statistics automatically (`CombatSystem._syncPlayerBuild`).
- Character & inventory save/load persisted atomically via `PlayerSaveSnapshot`, `DriftPlayerSaveRepository`, and `GameSessionCoordinator` (with lifecycle flush & 8-hour capped `OfflineProgressionService`).

## Acceptance Criteria

- [x] EXP is awarded correctly (normal, elite, boss, and configurable `DungeonCompletionReward` with overflow carry-over & `maxLevel` cap).
- [x] Character level increases correctly.
- [x] Gold is tracked correctly (`receiveReward`, `canAfford`, `spendGold`, and atomic `upgradeSkill` transaction validation).
- [x] Loot tables work (`LootService`, `loot_tables.json` incl. elite/boss/dungeon clear, all 5 rarities in `items.json`).
- [x] Items can be collected (with `RewardProcessor` duplicate-event prevention).
- [x] Inventory works (stackables, `maxStack: 1` non-stackables, optional slot/equipment bag capacity, `restore` snapshot).
- [x] Equipment can be equipped and removed (`EquipmentService` slot consistency & full-bag swap/unequip safety).
- [x] Equipment modifiers work.
- [x] Skills can be unlocked.
- [x] Skill levels work.
- [x] Automatic skill execution works.
- [x] All three specialization definitions exist.
- [x] Specialization modifiers work.
- [x] Skill and specialization integrate with combat.
- [x] Progression state can be persisted (Drift schema v2, atomic transactional save/load, recovery validation, `v1 -> v2` migration, & 8h bounded offline progression).
- [x] Relevant tests pass.

## Exit Condition

The character can defeat enemies, collect rewards, gain EXP, level up, manage equipment, use skills, and develop through specialization.

---

# MILESTONE 5 — DUNGEON SYSTEM

## Objective

Implement the room-based dungeon gameplay loop.

## Scope

### Dungeon Definitions
- Dungeon configuration.
- Room definitions.
- Room connections.
- Entry and exit positions.
- Spawn configuration.
- Completion conditions.
- Reward definitions.

### Dungeon Manager
- Start dungeon.
- Load room.
- Track active room.
- Detect room completion.
- Transition between rooms.
- End dungeon.
- Return to town.

### Room Management
- Room graph.
- Room loading.
- Room unloading.
- Enemy spawning.
- Enemy group management.
- Room state.

MVP uses a linear room sequence. The data model should support future branches.

### Forgotten Forest

Initial dungeon:

1. Forest Entrance.
2. Ancient Path.
3. Ruined Shrine.
4. Hidden Chamber.
5. Ancient Heart.

### Encounter Design

MVP content:
- Three normal monster types.
- One elite monster.
- One boss.

### Boss Encounter
- Boss spawn.
- Boss health.
- Boss AI.
- Boss attack patterns.
- Boss defeat.
- Boss reward.

### Dungeon Rewards
- Gold.
- EXP.
- Equipment.
- Materials.

## Acceptance Criteria

- [x] Dungeon can be started.
- [x] Rooms load correctly.
- [x] Enemies spawn according to configuration.
- [x] Room completion is detected.
- [x] Player transitions between rooms.
- [x] Elite encounter works.
- [x] Boss encounter works.
- [x] Boss defeat completes the dungeon.
- [x] Rewards are distributed correctly.
- [x] Failed runs follow established death rules.
- [x] Dungeon tests pass (`315/315` `flutter test`, `0` issues `flutter analyze`, APK debug terpasang & terbuka di `PFWS65SCTWIJFIEQ`).

## Exit Condition

The player can complete the entire Forgotten Forest dungeon automatically from the first room to the final boss.

---

# MILESTONE 6 — PERSISTENCE & OFFLINE PROGRESSION

## Objective

Make player progression persistent and support offline rewards.

## Scope

### Database
Use Drift/SQLite.

Persist:
- Player state.
- Character attributes and progression.
- Inventory.
- Equipment.
- Skills.
- Specialization.
- Dungeon progression.
- Game session.
- Revive state.
- Game settings.

### Save/Load
- Save player state.
- Load player state.
- Save inventory.
- Save equipment.
- Save skill progression.
- Save dungeon progression.
- Database migration.
- Transaction handling.
- Recovery from invalid or incomplete save data.

### Offline Simulation (Hybrid Offline Progression)
- Default fallback mode is **Pause Progression** (no silent offline simulation or farming without explicit player choice).
- Support two explicit offline modes:
  - **Mode A — Continue Dungeon:** Resume active dungeon run (`runId` preserved) from last room checkpoint, honoring `next_room_ids`, elite/boss encounters, completion conditions, death/revive rules, and stopping upon completion or failure without starting a new run.
  - **Mode B — Auto Farming:** Select an unlocked and previously cleared (`clearsCount > 0`) dungeon from Town; execute sequential fresh runs with unique `runId`s and per-run idempotent settlement while offline time remains; halt on failure (`stopOnDefeat` policy).
- Record last session/checkpoint timestamp and high-water clock guard.
- Calculate elapsed offline duration with negative/invalid clock rejection.
- Apply 8-hour reward cap.
- Simulate eligible progression deterministically via headless coarse/event simulation sharing domain combat, skill, loot, death/revive, and settlement rules (no Flame world when closed).
- Prevent duplicate rewards across restarts, recoveries, and interrupted simulations.
- Present pending Offline Summary upon return without re-triggering completed cycles.

Offline simulation must not run the Flame world while the application is closed.

Use a deterministic offline simulation service with explicit seed support for tests.

Avoid simulating every 50 ms tick for several hours. Use bounded event/coarse simulation reusing canonical domain formulas.

### Time Handling
- Use simulation time for active gameplay.
- Use wall-clock time for offline estimation.
- Clamp negative elapsed duration.
- Handle invalid timestamps.
- Do not claim perfect anti-cheat protection for a local-only offline game.

## Acceptance Criteria

- [x] Player data persists.
- [x] Player data loads correctly.
- [x] Inventory persists.
- [x] Equipment persists.
- [x] Skills persist.
- [x] Specialization persists.
- [x] Dungeon state persists appropriately.
- [x] Migrations work.
- [x] Offline duration is calculated correctly (`OfflineTimeCalculator`: 8h cap, clock guards, no zeroElapsed cursor advance).
- [x] Offline rewards respect the 8-hour cap.
- [x] Rewards cannot be claimed twice (`ClaimedRewards` offline time + `offline_kill` + room/dungeon keys & terminal state guard).
- [x] Offline simulation respects game rules (`OfflineDungeonRunner` headless parity for Mode A Continue Dungeon, Mode B Auto Farming `stopOnDefeat`, & Pause default).
- [x] Persistence tests pass.
- [x] Activity Selection UI & Offline Summary UI presentation integrated (M6 Stage 3: `TownHubView`, `DungeonScreen`, `OfflineSummaryOverlay`).

## Exit Condition

The game can close, reopen, restore player state, and calculate eligible offline progression consistently.

---

# MILESTONE 7 — POLISH & OPTIMIZATION

## Objective

Prepare Echoes of Aether for a stable MVP release.

## Scope

### Visual Polish
- Character animations.
- Monster animations.
- Skill effects.
- Dungeon transitions.
- UI polish.
- Damage feedback.
- Boss presentation.

### Audio
- Basic attack sound.
- Skill sound.
- Enemy sound.
- Loot sound.
- Level-up sound.
- Background music.
- Dungeon ambience.

### UI/UX
- Main menu.
- Character screen.
- Inventory screen.
- Equipment screen.
- Skill screen.
- Dungeon screen.
- Settings.
- Offline reward summary.

### Performance
- Sprite loading optimization.
- Object lifecycle management.
- Component cleanup.
- Memory usage.
- Frame performance.
- Database performance.
- Large enemy encounter testing.

### Balancing
- Character progression.
- Enemy difficulty.
- Skill damage.
- Equipment statistics.
- Loot probability.
- Boss difficulty.
- Offline rewards.

### Quality Assurance
- Regression testing.
- Integration testing.
- Android device testing.
- Save integrity testing.
- Gameplay loop testing.

## Acceptance Criteria

- [x] No critical gameplay bugs.
- [x] No critical save/load issues.
- [x] All MVP systems integrate correctly.
- [x] UI is usable (Town, Character/Skill Upgrade, Inventory, Equipment, Settings, HUD, Offline Summary & Activity Selection).
- [x] Audio works (`AudioService` + 8 original synthesized WAV assets + persistent `GameSettings`).
- [x] Animations work (16x16 nearest-neighbor `PixelSpriteAtlas`, `idle`/`walk`/`attack`/`downed`, Boss/Elite auras, `SkillVfxComponent`, & `RoomTransitionCurtain`).
- [x] Performance is acceptable on verified stress scenarios (24-enemy `CombatSimulation` & 20-enemy Flame view/VFX cleanup benchmarks; `app-release.apk` cold-launch `PFWS65SCTWIJFIEQ` clean, manual touch playtest noted).
- [x] Main gameplay loop works.
- [x] Regression tests pass (`366/366` `flutter test`, `0` issues `flutter analyze`).
- [x] Android build succeeds (`flutter build apk --debug` & `flutter build apk --release` 54.8MB + `PFWS65SCTWIJFIEQ` install & launch `PID=32483`).

## Exit Condition

The MVP is stable enough for internal testing and further content expansion.

---

# 4. MVP SCOPE CONTROL

The following features are explicitly postponed.

Do not implement them as part of the current MVP unless the project owner changes the scope.

- Multiplayer gameplay.
- Guild system.
- PvP.
- Player trading.
- Gacha.
- Pet system.
- Procedural dungeon generation.
- Complex crafting.
- Multiple playable characters.
- Online account synchronization.
- Server infrastructure.
- Advanced social features.

Future compatibility is welcome, but unnecessary implementation is not.

---

# 5. CROSS-MILESTONE DEPENDENCIES

The intended dependency sequence:

M1 Project Foundation
  -> M2 World & Player
  -> M3 Combat System
  -> M4 RPG Progression
  -> M5 Dungeon System
  -> M6 Persistence & Offline Progression
  -> M7 Polish & Optimization

Important integration dependencies:

- M2 movement is required by M3 combat navigation.
- M3 combat is required by M4 progression rewards.
- M4 character progression is required by M5 dungeon reward and difficulty integration.
- M5 dungeon state must integrate with M6 persistence.
- M6 persistence must be stable before M7 release preparation.

The roadmap describes the main sequence, not a prohibition against parallel development of independent features.

---

# 6. DEVELOPMENT GOVERNANCE FOR AI AGENTS

This section is mandatory for every AI Agent working on Echoes of Aether.

## 6.1 Before Starting Any Task

The agent must:

1. Inspect the repository.
2. Read this Master Development Roadmap.
3. Read the available GDD and technical documentation.
4. Identify the current milestone.
5. Identify the current implementation state.
6. Inspect relevant tests.
7. Avoid duplicating completed functionality.

## 6.2 Implementation Rules

- Preserve existing working features.
- Follow current architecture.
- Do not rebuild working systems without justification.
- Do not introduce unnecessary dependencies.
- Do not implement postponed features.
- Do not use placeholder logic as completed functionality.
- Keep balancing values configurable.
- Add tests for gameplay logic.
- Run analyzer and tests after changes.
- Document migrations and breaking changes.

## 6.3 Scope Discipline

The agent must not independently:

- Change core game design.
- Change the combat model.
- Change automatic movement to manual movement.
- Replace the one-character specialization model.
- Introduce online dependencies into offline-first MVP.
- Expand MVP scope without approval.

If a design conflict is discovered, report it and request a decision rather than silently changing the design.

## 6.4 Milestone Status

Use these statuses:

- NOT STARTED
- IN PROGRESS
- BLOCKED
- READY FOR REVIEW
- COMPLETED

A milestone can only be marked COMPLETED when all required acceptance criteria are satisfied and verified.

Do not mark a milestone complete merely because its implementation files exist.

## 6.5 Required Progress Report

At the end of each development task, report:

1. Current milestone.
2. Current phase.
3. Completed work.
4. Remaining work.
5. New files.
6. Modified files.
7. Tests executed.
8. Analyzer results.
9. Known issues.
10. Recommended next task.

Always distinguish implemented, tested, and verified functionality.

---

# 7. CURRENT PROJECT STATUS

This document defines the intended roadmap, not the actual completion status of the repository.

The AI Agent must audit the repository before assigning milestone completion.

Known project context:

- M1 through M3 have been the preceding development milestones.
- The project is currently working on M4.
- Current focus: Skill System and Class Specialization foundation.

The agent must verify actual repository state and report the exact status of every milestone.

---

# 8. FINAL DEVELOPMENT PRINCIPLE

Build Echoes of Aether incrementally.

Prioritize:
1. Correct gameplay logic.
2. Stable architecture.
3. Reliable persistence.
4. Testable systems.
5. Consistent visual presentation.
6. Content expansion.

A feature is not complete merely because it appears on screen.

It must work, integrate with the game systems, preserve state correctly where required, and pass its relevant tests.

**The goal is a cohesive, maintainable, fully playable Idle Dungeon RPG MVP — not a collection of disconnected features.**