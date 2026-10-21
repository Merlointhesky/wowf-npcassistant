# ForeverNPCAssistant

**Version:** 1.0.1  
**Author:** merlointhesky (Merlointhesky)  
**License:** MIT

---

## Overview

ForeverNPCAssistant is a World of Warcraft Classic Beta add‑on that automates repetitive NPC interactions such as quest acceptance/completion and gossip dialogs. It is built to work with the **WoW Forever Beta** client, leveraging the modern `C_` API namespaces where possible while gracefully falling back to legacy functions when needed.

---

## Features

- **Quest Automation** – Automatically accept, turn in, and complete quests when you talk to quest‑givers.
- **Gossip Automation** – Skips unnecessary gossip windows and selects the appropriate options for you.
- **Event‑driven Architecture** – Listens to the relevant Blizzard events (`QUEST_DETAIL`, `GOSSIP_SHOW`, etc.) and reacts instantly.
- **Modern API First** – Uses `C_TradeSkillUI`, `C_Container`, `C_Item`, `C_CurrencyInfo`, and other `C_` APIs before falling back to the classic globals.
- **Safe Logout Handling** – Avoids the `PLAYER_LOGOUT` teardown pitfalls by only saving offline timers during logout.

---

## Installation

1. Download or clone the repository into your WoW Classic Beta AddOns directory:
   ```
   c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverNPCAssistant
   ```
2. Ensure the folder contains the following files:
   - `ForeverNPCAssistant.toc`
   - `core.lua`
   - `quest_automation.lua`
   - `gossip_automation.lua`
   - `README.md`
3. Restart the game or reload the UI (`/reload`). The add‑on should appear in the AddOns list.

---

## Usage

The add‑on works automatically once enabled. No additional UI is exposed, but you can toggle its behaviour via the following slash commands:

- `/npcassist on` – Enable automation (default).
- `/npcassist off` – Disable automation for the current session.
- `/npcassist status` – Print the current state to the chat frame.

The add‑on respects the standard WoW combat lock‑down; automation is paused while you are in combat and resumes afterwards.

---

## API Details & Compatibility

### Modern API Preference
The **WoW Forever Beta** client mixes a modern retail engine with a Classic wrapper. To ensure forward compatibility we:

- **Prioritize `C_` namespaces** (e.g., `C_Item.GetItemInfo`).
- **Fallback to legacy globals** only when the modern call is unavailable.
- **Update event hooks** to use the newer event names (e.g., `TRADE_SKILL_LIST_UPDATE` instead of the removed `TRADE_SKILL_UPDATE`).

### Known Edge Cases
- **Logout Teardown** – Do **not** query live character state (`GetMoney()`, `UnitClassBase()`) inside `PLAYER_LOGOUT`; data may be corrupted. The add‑on only records offline timers during logout.
- **Return Value Shifts** – Functions like `GetInboxItem()` now return `itemID` as the second return value. The code accounts for this by explicitly naming each returned variable.

---

## Configuration

Configuration is stored in the saved variables file `ForeverNPCAssistant.lua`. You can edit the following settings manually:

```lua
ForeverNPCAssistant = {
  enableQuestAutomation = true,
  enableGossipAutomation = true,
  debugMode = false,
}
```

Set `debugMode = true` to see diagnostic messages in the chat frame.

---

## Development

If you wish to contribute:

1. Fork the repository.
2. Make your changes in the `core.lua`, `quest_automation.lua`, or `gossip_automation.lua` files.
3. Run a `/reload` in‑game to test.
4. Submit a pull request.

Please keep the **modern API first** rule in mind when adding new functionality.

---

## License

Distributed under the MIT License. See the `LICENSE` file for details.

---

## Support

For questions or bug reports, join the Discord channel *#forever-npc-assist* or create an issue on the GitHub repository.
## Repository

[GitHub Repository](https://github.com/Merlointhesky/wowf-npcassistant)
