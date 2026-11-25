# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog (https://keepachangelog.com/en/1.0.0/),
and this project adheres to Semantic Versioning (https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-11-25

### Fixed
- **Reliable Quest Auto-Pickup from Gossip & Greeting Panels**: Added automatic selection of available quests and completable active quests directly on `GOSSIP_SHOW` and `QUEST_GREETING` frames, plus resilient `QUEST_DETAIL` acceptance when custom quest UIs or multi-quest panels are active.

### Added
- **Multi-Quest Rotation**: When an NPC offers multiple quests, automatically filters out quests already in the player's quest log and rotates through remaining unaccepted quests.
- **Low-Level (Trivial) Quest Filtering & Minimap Tracking Detection**: By default, low-level (gray) quests are ignored unless the player has **Track Low-Level Quests** enabled on the minimap or enables the new **"Always auto-accept low-level quests"** option (`/npcassist lowlevel`).

---
## [1.1.0] - 2026-11-07

### Fixed
- **Target Equipped Item Display in Upgrade Popup**: Fixed dual-slot items (Rings, Trinkets, 1H Weapons) overwriting equipped items with `(Nothing Equipped)` when the second slot was empty, and properly resolved 1H vs. 2H vs. Off-Hand/Shield weapon comparisons.
- **Reliable Equipped Tooltip Rendering**: Populates embedded comparison tooltips via `SetInventoryItem("player", slot)` with fallback to `SetHyperlink`, plus deferred layout sizing so tooltips never clip or fail to appear.
- **Vendor & Gossip Automation**: Fixed a nil-call Lua error on `addon.debug` in `vendor_automation.lua`, eliminated duplicate `SelectOption` + `SelectGossipOption(1)` calls in `gossip_automation.lua`, and unified all events through `FNPA.Events`.
- **Debug Hook Performance**: Removed global Frame metatable `Show`/`Hide` hooks that caused chat spam when debug mode was enabled.

### Added
- **Tooltip-Based Item Stat Scanner & Color-Coded Stat Diff (`+` Green / `-` Red)**: Accurately parses Armor, Block, Weapon Damage/Speed/DPS, Primary/Secondary Stats, and green `"Equip:"`/`"Use:"` effects from tooltips, displaying exact `+` (green) and `-` (red) stat deltas (`old -> new`).
- **Class Proficiency & Stat Weighting**: Filters out unusable red-text armor/weapon types and weights stats by player class.
- **Guaranteed Quest Reward Support & Safe Equip Queue**: Prompts for guaranteed (non-choice) quest equipment upgrades and safely waits for bag arrival (`BAG_UPDATE_DELAYED`) and combat end (`PLAYER_REGEN_ENABLED`) before equipping.
- **Options & Slash Commands**: Added `"Prompt to equip upgrade rewards"` option, live status on the Minimap button tooltip, a `"Test Popup"` button, and `/npcassist` (`/fnpa`) slash commands (`on`, `off`, `status`, `test`, `debug`).

---
## [1.0.2] - 2026-10-22
- improved upgrade detection and scoring
- improved upgrade popup

## [1.0.1] - 2026-10-21
- added auto reward equip if upgrade is suggested.

## [1.0.0] - 2026-10-19

### Added
- Initial release of ForeverNPCAssistant.
- Core functionality files: `core.lua`, `quest_automation.lua`, `gossip_automation.lua`, `vendor_automation.lua`, `options.lua`.
- README with usage instructions and overview.
- TOC and basic metadata.
- Basic icon (`logo.jpg`).
