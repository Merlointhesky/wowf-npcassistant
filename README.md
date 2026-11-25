# ForeverNPCAssistant

**Version:** 1.2.0  
**Author:** merlointhesky (Merlointhesky)  
**License:** GNU General Public License v3.0 (GPL-3.0)

---

## Overview

ForeverNPCAssistant is a World of Warcraft Forever (1.6 / Interface `16001`) add‑on that automates repetitive NPC interactions such as quest acceptance/completion, single-option gossip/vendor dialogs, and quest reward upgrade highlighting with a side-by-side equip prompt and color-coded stat comparisons.

---

## Features

- **Quest Automation & Multi-Quest Rotation** – Automatically selects, accepts, progresses, and completes quests from both gossip (`GOSSIP_SHOW`) and greeting (`QUEST_GREETING`) dialogs, rotating through multiple available quests that haven't been picked up yet (hold `Shift` to bypass).
- **Smart Low-Level Quest Filtering** – Ignores trivial (low-level) quests by default unless you are actively tracking low-level quests on the minimap or enable **Always auto-accept low-level quests** in the options panel (`/npcassist lowlevel`).
- **Gossip & Vendor Automation** – Skips single-option gossip dialogs and 2-step vendor gossip menus when no quests are available.
- **Upgrade Reward Highlighting** – Evaluates quest reward choices using class-weighted stats, weapon DPS, armor proficiency, and item level, highlighting the top upgrade with a green border and `^` indicator.
- **Side-by-Side Upgrade Equip Prompt & Stat Diff** – Displays the new quest reward alongside your currently equipped item(s) with color-coded `+` (green) and `-` (red) stat deltas (`old -> new`) and a one-click **Equip Upgrade** button.
- **Minimap Button & Options Panel** – Left-click the minimap button or run `/npcassist` (`/fnpa`) to toggle any automation feature or test the upgrade popup.

---

## Installation

1. Copy `ForeverNPCAssistant` into your WoW Forever AddOns directory:
   ```
   c:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ForeverNPCAssistant
   ```
2. Restart the game or reload the UI (`/reload`).

---

## Usage & Slash Commands

- `/npcassist` or `/fnpa` – Open/close the options panel.
- `/npcassist on` – Enable quest & gossip automation.
- `/npcassist off` – Disable quest & gossip automation.
- `/npcassist lowlevel` – Toggle always auto-accepting low-level quests.
- `/npcassist status` – Print current settings to chat.
- `/npcassist test` – Preview the side-by-side upgrade popup using your currently equipped gear.
- `/npcassist debug` – Toggle diagnostic event logging.

Hold **Shift** while interacting with an NPC to temporarily pause automation.

---

## Configuration

Settings are stored in `ForeverNPCAssistantDB`:

```lua
ForeverNPCAssistantDB = {
  autoAccept = true,
  acceptLowLevelQuests = false,
  autoComplete = true,
  autoSkipGossip = true,
  rewardHighlight = true,
  autoEquipPrompt = true,
  minimapPos = 225,
  debugUI = false,
}
```

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0). See the [LICENSE](LICENSE) file for complete details.

## Repository

[GitHub Repository](https://github.com/Merlointhesky/wowf-npcassistant)
