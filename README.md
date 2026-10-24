# Evomon [S3 TRADE] - WindUI Automation Hub

Full automation, auto-quest storyline completer, battle engager, and radar script for **Evomon [S3 TRADE]** built with **WindUI**.

---

## ⚡ Quick Loadstring

Run this code in any modern Roblox executor:

```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/gametil/evomon-hub/main/EvomonHub.luau"))()
```

*(Alternative short entrypoint)*:
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/gametil/evomon-hub/main/main.lua"))()
```

---

## ✨ Features

### 📜 Full Auto Quest & Storyline Completer (NEW!)
- **Follows Any Quest**: Dynamically reads your active storyline or side quest using `TaskController` and `GoalConfig`.
- **Target Evomon Hunter**: Automatically identifies the specific Evomon required by the quest (e.g. Datubud in Amber Acres), teleports to it, and initiates battle.
- **NPC Dialogue & Boss Solver**: Automatically interacts with NPCs and challenges quest bosses.
- **Auto Turn-In & Claim**: The instant a quest is finished, the bot automatically turns it in via `ReqCompleteTask`, collects all gems & rewards, closes popups, and accepts the next quest in line!
- **Live Quest Dashboard**: Displays live Quest Name, Task ID, Current/Target progress, and Claim status directly in the WindUI hub.

### 🏝️ Island Progression Auto Farm & Active Combat
- **Active Battle Initiator**: Teleports to wild Evomons and immediately triggers combat using `BattleService.enterPetBattle`.
- **Island Progression**: Automatically farms the configured quota of Evomons on the current island, then warps to the next island and repeats until reaching the World Boss.
- **World Boss Auto-Fight**: Direct waypoint and boss fight trigger for World Boss Island.
- **Fight Closest Evomon Now**: One-click button to warp to and instantly engage the closest wild Evomon.

### ⚔️ In-Game Auto Battle ('V' Mode) Control
- **True Toggle Off**: Fixed the bug where clicking 'V' off would immediately force it back on every frame. Now applies cleanly once upon combat entry, and respects your toggles.
- **UI Toggle**: Easily switch Auto Battle on or off directly inside the WindUI hub.

### 🌟 Level Up & Reward Automation
- **Auto Level Breakthrough**: Automatically invokes level breakthrough (`ReqLevelBreakthrough`) so your Evomons and character never get stuck at level caps.
- **Auto Claim Level Rewards**: Automatically claims player level rewards (`ReqClaimPlayerLevelReward`).
- **Auto Dismiss Popups**: Automatically closes `GetRewardPopUpWindow`, `LevelUPEffectWindow`, and skill replacement prompts after battle so your bot never freezes.

### 🐾 Wild Evomon Radar & Clean ESP
- **Live World Radar**: Scans and tracks wild Evomons across the map in real-time.
- **Clean ESP Visualizer**: Shows billboard tags with Name, Level, and distance. Completely wipes all anchor parts and GUIs immediately when toggled OFF.
- **Fast Travel**:
  - `Teleport To Closest Evomon`
  - `Teleport To Highest Level Evomon`

### 🎁 One-Click Rewards & Promo Codes
- **Batch Redeem Active Codes**: One-click redemption for all active codes (`240evoRISE`, `EVO120HYPE`, `EVO60SPARK`, `30K-LIKES`, `20000LIKES`, `THXFOR5K`, `2K-LIKES`, `12klikes`).
- **Custom Code Input**: Test and redeem any new promo code.
- **Auto Claim All Mail**: Instantly claims all mailbox rewards.
- **Auto Claim Daily & Group Rewards**: One-click collection for daily streaks and group bonuses.

### 🗺️ World & Island Teleports
- Direct waypoints to all 15 Islands (Verdant Valley, Petal Pond, Lava Crag, Amber Acres, Autumn Hill, Shiver Snows, Raven Ridge, Silent Sands, Crystal Cascade, Dusk Town, Canyon Oasis, Murkwood, Nether Land, Rocky Ridge, Thunder Cliffs) + World Boss Island.
- Fast access to S3 Trading Hall.

### 🏃 Player Mods & Utilities
- Custom WalkSpeed (16 - 150) & JumpPower (50 - 250).
- Infinite Jump & NoClip.
- **Anti-AFK Protection**: Prevents Roblox's 20-minute idle disconnect.
