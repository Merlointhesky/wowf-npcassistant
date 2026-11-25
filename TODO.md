# FOREVER NPC ASSISTANT

## RESOLVED BUGS & FEATURES (v1.2.0)
- [x] **BUG**: Quest auto-pickup now automatically selects available quests and completable active quests directly on `GOSSIP_SHOW` and `QUEST_GREETING` panels and reliably accepts quests on `QUEST_DETAIL`.
- [x] **FEATURE**: Multi-quest NPCs now rotate through unaccepted quests, skipping quests already in the player's quest log.
- [x] **FEATURE**: Low-level (trivial) quests are ignored by default unless **Track Low-Level Quests** is enabled on the minimap or **"Always auto-accept low-level quests"** (`/npcassist lowlevel`) is enabled in options.

## RESOLVED BUGS & FEATURES (v1.1.0)
- [x] **BUG**: Auto equip of quest reward now accurately resolves and displays the target equipped item(s) across single-slot armor, dual-slot rings/trinkets, and 1H/2H/Off-hand weapon combinations using `SetInventoryItem("player", slot)`.
- [x] **FEATURE**: Auto equip of quest reward now displays a full color-coded stat difference summary (`+` in green, `-` in red, with `(old -> new)` values) covering Item Level, Weapon DPS & Speed, Armor, Primary/Secondary stats, and `Equip:`/`Use:` effects.
