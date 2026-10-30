--[[
    Evomon [S3 TRADE] - WindUI Automation Hub
    Reverse engineered & automated via Real MCP
    WindUI Modern Interface

    Features:
      - Full Auto Quest & Storyline Completer (Hunts target Evomons, talks to NPCs, claims rewards, advances quests)
      - Clean ESP Visualizer (Bug-free instant wipe on toggle OFF)
      - Island Progression Auto Farm (Farms island, advances to next island, kills boss)
      - Active Wild Evomon Fighting (Teleports & initiates battle via BattleService)
      - Controlled In-Game Auto Battle 'V' Mode (Applied once on entry; toggle OFF actually stays OFF)
      - Auto Level Breakthrough & Auto Claim Level Rewards
      - Auto Dismiss Popups & Level-Up Windows (Prevents UI lockups during farming)
      - Wild Evomon Radar & Instant Fight / Teleports
      - Boss Island & World Boss Farm
      - One-Click Auto Redeem All Active Codes
      - Auto Claim Mail, Daily, & Group Rewards
      - All 15 Island Coordinates & Instant Waypoints
      - Player Mods (WalkSpeed, JumpPower, Infinite Jump, NoClip, Anti-AFK)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- Teardown previous instances if running via Real MCP live-reload or standalone
if getgenv and getgenv()._EvomonHubTeardown then
    pcall(getgenv()._EvomonHubTeardown)
end

-- Wait for game core modules & remotes
local Remote = ReplicatedStorage:WaitForChild("Remote", 30)
if not Remote then
    warn("[EvomonHub] Remote folder not found in ReplicatedStorage")
    return
end

local Config = ReplicatedStorage:WaitForChild("Config", 30)
local PetConfig = Config and require(Config:WaitForChild("PetConfig", 10))
local GoalConfig = Config and require(Config:WaitForChild("GoalConfig", 10))
local BattlePoolConfig = nil
pcall(function()
    BattlePoolConfig = require(ReplicatedStorage.Config.BattlePoolConfig)
end)
local BattleTrainerConfig = nil
pcall(function()
    BattleTrainerConfig = require(ReplicatedStorage.Config.BattleTrainerConfig)
end)
local UIManager = require(ReplicatedStorage.Core.UI.UIManager)

local BattleService = nil
pcall(function()
    BattleService = require(ReplicatedStorage:WaitForChild("Script", 10):WaitForChild("Battle", 10):WaitForChild("BattleService", 10))
end)

-- Dedicated Containers for Clean ESP (Zero leftovers on toggle OFF)
local ESPContainerFolder = workspace.Terrain:FindFirstChild("TerrainCache")
if not ESPContainerFolder then
    ESPContainerFolder = Instance.new("Folder")
    ESPContainerFolder.Name = "TerrainCache"
    ESPContainerFolder.Parent = workspace.Terrain
end

local ESPGui = (gethui and gethui():FindFirstChild("Evomon_ESP_Gui")) or game:GetService("CoreGui"):FindFirstChild("Evomon_ESP_Gui")
if not ESPGui then
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "Evomon_ESP_Gui"
    ESPGui.ResetOnSpawn = false
    ESPGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Create Window
local Window = WindUI:CreateWindow({
    Title = "Evomon Hub [S3 TRADE]",
    Icon = "sparkles",
    Author = "by Antigravity & WindUI",
    Folder = "EvomonHubConfig",
    Size = UDim2.fromOffset(640, 540),
    Theme = "Dark",
    Transparent = true,
    Resizable = true,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    OpenButton = {
        Title = "Open Evomon Hub",
        Icon = "sparkles",
        CornerRadius = UDim.new(0, 16),
        StrokeThickness = 2,
        Color = ColorSequence.new(
            Color3.fromHex("8B5CF6"),
            Color3.fromHex("EC4899")
        ),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    }
})

-- Island Coordinates Directory
local IslandData = {
    {id = 1, name = "Island 1 (Verdant Valley)", pos = Vector3.new(8312, 632, 150)},
    {id = 2, name = "Island 2 (Petal Pond)", pos = Vector3.new(9470, 665, -916)},
    {id = 3, name = "Island 3 (Lava Crag)", pos = Vector3.new(9682, 768, -3043)},
    {id = 4, name = "Island 4 (Amber Acres)", pos = Vector3.new(11078, 637, -4550)},
    {id = 5, name = "Island 5 (Autumn Hill)", pos = Vector3.new(11830, 523, -5963)},
    {id = 6, name = "Island 6 (Shiver Snows)", pos = Vector3.new(11480, 699, -7730)},
    {id = 7, name = "Island 7 (Raven Ridge)", pos = Vector3.new(14530, 591, -8818)},
    {id = 8, name = "Island 8 (Silent Sands)", pos = Vector3.new(16357, 551, -9046)},
    {id = 9, name = "Island 9 (Crystal Cascade)", pos = Vector3.new(17665, 565, -7634)},
    {id = 10, name = "Island 10 (Dusk Town)", pos = Vector3.new(19353, 645, -7567)},
    {id = 11, name = "Island 11 (Canyon Oasis)", pos = Vector3.new(20024, 538, -10747)},
    {id = 12, name = "Island 12 (Murkwood)", pos = Vector3.new(19000, 530, -12769)},
    {id = 13, name = "Island 13 (Nether Land)", pos = Vector3.new(17425, 542, -14201)},
    {id = 14, name = "Island 14 (Rocky Ridge)", pos = Vector3.new(15551, 527, -15459)},
    {id = 15, name = "Island 15 (Thunder Cliffs)", pos = Vector3.new(13213, 539, -16174)},
    {id = 99, name = "World Boss Island", pos = Vector3.new(12654, 598, -9070)},
}

-- State Variables
local HubState = {
    Running = true,
    -- Auto Quest System
    AutoQuest = false,
    AutoQuestClaim = true,
    QuestStepDelay = 1.8,
    LastQuestStep = 0,
    AutoChallengeBoss = true, -- Auto detect and challenge Island King/Bosses (e.g. Pebgolem King in Verdant Valley)
    AutoNavigateToQuestIsland = true, -- Auto travel to quest-required island if outside current territory
    CurrentQuestObjective = "None",
    CurrentQuestIsland = "None",
    -- Island Progression Auto Farm
    IslandAutoFarm = false,
    CurrentIslandIndex = 1,
    FarmsPerIsland = 5,
    FarmsOnCurrentIsland = 0,
    AutoKillBoss = true,
    FarmRadius = 600,
    -- Battle & Level Up
    AutoBattle = false, -- Default false: SmartCombatAI executes optimal elemental moves instead of server Ram spam
    SmartCombatAI = true,
    AutoSwitchPetCounter = true,
    AutoPickBestMove = true,
    AutoCastUltimate = true,
    LastTurnMoveTime = 0,
    CurrentEnemyElement = nil,
    CurrentEnemyName = "None",
    AutoLevelBreakthrough = true,
    AutoClaimLevelRewards = true,
    AutoDismissPopups = true,
    AutoEscapeIfHighLevel = false,
    EscapeLevelThreshold = 100,
    -- Movement & Safety (Anti-Cheat Protection)
    MovementMode = "Walk", -- "Walk" (Safe Humanoid MoveTo / No TP - 100% Safe), "Blink" (Chunk-Hop Blink TP), "Tween" (Smooth Glide)
    WalkSpeedBoost = 16, -- Default vanilla 16 walkspeed for 100% legit movement
    ArrivalDistance = 8,
    BlinkChunkSize = 45, -- Max studs per micro-hop (bypasses server delta position checks)
    BlinkDelay = 0.05, -- Micro-delay between hops
    PostTpDelay = 0.4, -- Stabilization delay after TP before sending action
    IsNavigating = false,
    -- ESP
    EvomonESP = false,
    ESPObjects = {},
    -- Player Mods
    SpeedEnabled = false,
    CustomSpeed = 16,
    JumpEnabled = false,
    CustomJump = 50,
    InfJump = false, -- Disabled: High detection risk
    NoClip = false, -- Disabled: High detection risk
    AntiAFK = true,
    -- Internals
    Connections = {},
    CachedCreatures = {},
    LastCreatureScan = 0,
    LastFarmTeleport = 0,
    LastPeriodicCheck = 0,
    FarmDelay = 3.2, -- Safe 3.2s cadence to avoid server rate-limiting
    ClosestEvomon = nil,
    LastBattleState = false,
}

-- Complete ESP Cleanup (destroys every anchor, billboard, and cache)
local function ClearAllESP()
    pcall(function()
        if ESPContainerFolder then
            ESPContainerFolder:ClearAllChildren()
        end
        if ESPGui then
            ESPGui:ClearAllChildren()
        end
    end)
    for uid, item in pairs(HubState.ESPObjects) do
        pcall(function()
            if typeof(item) == "table" then
                if item.gui then item.gui:Destroy() end
                if item.part then item.part:Destroy() end
            elseif typeof(item) == "Instance" then
                item:Destroy()
            end
        end)
    end
    table.clear(HubState.ESPObjects)
end

-- Cleanup function for unloads
local function Cleanup()
    HubState.Running = false
    for _, conn in ipairs(HubState.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(HubState.Connections)

    ClearAllESP()

    -- Reset character modifications
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        pcall(function()
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
            LocalPlayer.Character.Humanoid.JumpPower = 50
        end)
    end

    pcall(function() Window:Destroy() end)
end

if getgenv then
    getgenv()._EvomonHubTeardown = Cleanup
end

if typeof(STATE) == "table" and STATE.onCleanup then
    STATE.onCleanup(Cleanup)
end

-- ====================
-- HELPER FUNCTIONS
-- ====================

local function GetRootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Check if a specific window is open in UIManager
local function IsWindowOpen(name)
    local open = UIManager:getOpenedUIWindowList()
    for _, w in ipairs(open or {}) do
        if w.name == name then
            return true, w
        end
    end
    return false, nil
end

-- Check if currently in battle
local function IsInBattle()
    local open, bw = IsWindowOpen("MainBattleWindow")
    if open then
        return true, bw
    end
    if BattleService and BattleService.hasActiveBattleSession and BattleService.hasActiveBattleSession() then
        return true, nil
    end
    return false, nil
end

-- Safe Movement Engine: Walks smoothly using Humanoid:MoveTo / Pathfinding to completely eliminate TP detection risks
local function SafeMoveTo(cfOrPos, stopDistance, timeoutSec)
    stopDistance = stopDistance or HubState.ArrivalDistance or 8
    timeoutSec = timeoutSec or 12

    local targetPos = nil
    if typeof(cfOrPos) == "CFrame" then
        targetPos = cfOrPos.Position
    elseif typeof(cfOrPos) == "Vector3" then
        targetPos = cfOrPos
    end
    if not targetPos then return false end

    local root = GetRootPart()
    local hum = GetHumanoid()
    if not root or not hum then return false end

    local dist = (root.Position - targetPos).Magnitude
    if dist <= stopDistance then return true end

    -- Mode 1: Chunk-Hop Blink (Break large distance into small legit hops)
    if HubState.MovementMode == "Blink" then
        local chunkSize = HubState.BlinkChunkSize or 45
        local hopDelay = HubState.BlinkDelay or 0.05
        local totalDist = (root.Position - targetPos).Magnitude
        local steps = math.max(1, math.ceil(totalDist / chunkSize))
        local startPos = root.Position

        for step = 1, steps do
            if IsInBattle() or not HubState.Running then return true end
            local alpha = step / steps
            local nextPos = startPos:Lerp(targetPos, alpha)
            root.CFrame = CFrame.new(nextPos + Vector3.new(0, 2.5, 0))
            task.wait(hopDelay)
        end
        task.wait(HubState.PostTpDelay or 0.4)
        return true
    end

    -- Cross-island / Long-distance transit (> 1000 studs across oceans)
    if dist > 1000 then
        local TweenService = game:GetService("TweenService")
        local glideDuration = math.clamp(dist / 140, 2, 7)
        local tweenInfo = TweenInfo.new(glideDuration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(root, tweenInfo, { CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0)) })
        tween:Play()
        local elapsed = 0
        while elapsed < glideDuration do
            if IsInBattle() then tween:Cancel(); return true end
            task.wait(0.1)
            elapsed = elapsed + 0.1
        end
        return (root.Position - targetPos).Magnitude <= (stopDistance + 10)
    end

    -- Mode 2: Smooth Glide (Tween)
    if HubState.MovementMode == "Tween" then
        local TweenService = game:GetService("TweenService")
        local speed = HubState.WalkSpeedBoost or 26
        local duration = math.clamp(dist / speed, 0.2, timeoutSec)
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(root, tweenInfo, { CFrame = CFrame.new(targetPos + Vector3.new(0, 3.2, 0)) })
        tween:Play()
        local elapsed = 0
        while elapsed < duration do
            if IsInBattle() then tween:Cancel(); return true end
            task.wait(0.08)
            elapsed = elapsed + 0.08
        end
        return (root.Position - targetPos).Magnitude <= (stopDistance + 6)
    end

    -- Mode 3 (Default): Legit Humanoid Walk (100% Safe, zero teleport detection)
    HubState.IsNavigating = true
    -- Apply safe natural walking speed (22 - 26) so bot walks briskly without delaying
    if HubState.SpeedEnabled and HubState.CustomSpeed then
        hum.WalkSpeed = HubState.CustomSpeed
    elseif hum.WalkSpeed < 22 then
        hum.WalkSpeed = 24
    end

    local startTime = os.clock()
    local lastPos = root.Position
    local stuckTicks = 0

    -- For medium-to-long paths (> 35 studs), compute obstacle-aware waypoints
    if dist > 35 then
        local PathfindingService = game:GetService("PathfindingService")
        local path = PathfindingService:CreatePath({
            AgentRadius = 2.5,
            AgentHeight = 5.0,
            AgentCanJump = true,
            WaypointSpacing = 8
        })
        local ok = pcall(function()
            path:ComputeAsync(root.Position, targetPos)
        end)

        if ok and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for i = 2, #waypoints do
                if IsInBattle() or not HubState.Running then
                    HubState.IsNavigating = false
                    return true
                end
                if (os.clock() - startTime) > timeoutSec then break end

                local wp = waypoints[i]
                if wp.Action == Enum.PathWaypointAction.Jump then
                    hum.Jump = true
                end

                hum:MoveTo(wp.Position)
                local stepT0 = os.clock()
                while (os.clock() - stepT0) < 2.5 do
                    if IsInBattle() then
                        HubState.IsNavigating = false
                        return true
                    end
                    local curD = (root.Position - wp.Position).Magnitude
                    if curD <= 6 or (root.Position - targetPos).Magnitude <= stopDistance then
                        break
                    end
                    task.wait(0.06)
                end
            end
        end
    end

    -- Direct approach to destination (Humanoid Walking Mode)
    while (os.clock() - startTime) < timeoutSec do
        if IsInBattle() or not HubState.Running then
            hum:Move(Vector3.zero)
            HubState.IsNavigating = false
            return true
        end

        local curDist = (root.Position - targetPos).Magnitude
        if curDist <= stopDistance then
            hum:Move(Vector3.zero)
            HubState.IsNavigating = false
            return true
        end

        hum:MoveTo(targetPos)

        -- Keep character facing target & walking
        local moveDir = (targetPos - root.Position)
        local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
        if flatDir.Magnitude > 0.1 then
            hum:Move(flatDir.Unit)
        end

        -- Unstuck detection & natural jump over obstacles
        if (root.Position - lastPos).Magnitude < 0.8 then
            stuckTicks = stuckTicks + 1
            if stuckTicks >= 3 then
                hum.Jump = true
                stuckTicks = 0
            end
        else
            stuckTicks = 0
        end
        lastPos = root.Position

        task.wait(0.08)
    end

    hum:Move(Vector3.zero)
    HubState.IsNavigating = false
    local finalDist = (root.Position - targetPos).Magnitude
    if finalDist <= (stopDistance + 6) then
        return true
    end

    -- Pure Walking Mode: Zero teleportations or instant CFrame sets
    return finalDist <= (stopDistance + 6)
end

-- Safe Movement router: routes all waypoints and travel through SafeMoveTo (Legit Walk by default)
local function TeleportTo(cf)
    return SafeMoveTo(cf, HubState.ArrivalDistance or 8)
end

-- [moved above SafeMoveTo]

-- [moved above SafeMoveTo]

-- Safely set in-game Auto Battle ('V' button) without spamming
local function SetAutoBattleState(enable)
    if not BattleService then return end
    pcall(function()
        BattleService.autoBattle(enable)
    end)
    local inBattle, battleWin = IsWindowOpen("MainBattleWindow")
    if inBattle and battleWin then
        pcall(function()
            if battleWin.setAutoButton then
                battleWin:setAutoButton(enable)
            elseif battleWin.class and battleWin.class.setAutoButton then
                battleWin.class.setAutoButton(battleWin, enable)
            end
            if enable and battleWin.AutoButton then
                for _, c in ipairs(getconnections(battleWin.AutoButton.MouseButton1Click)) do c:Fire() end
                for _, c in ipairs(getconnections(battleWin.AutoButton.Activated)) do c:Fire() end
            end
        end)
    end
end

-- ===================================================
-- SMART ELEMENTAL COMBAT & DAMAGE OPTIMIZER ENGINE
-- ===================================================

local ElementNames = {
    [1] = "Normal", [2] = "Fire", [3] = "Water", [4] = "Grass",
    [5] = "Electric", [6] = "Ice", [7] = "Fighting", [8] = "Ground",
    [9] = "Rock", [10] = "Flying", [11] = "Bug", [12] = "Dragon",
    [13] = "Psychic", [14] = "Poison", [15] = "Light", [16] = "Dark",
    [17] = "Steel"
}

local ElementIcons = {
    [1] = "⚪", [2] = "🔥", [3] = "💧", [4] = "🌿",
    [5] = "⚡", [6] = "❄️", [7] = "🥊", [8] = "🏜️",
    [9] = "🪨", [10] = "🦅", [11] = "🐛", [12] = "🐉",
    [13] = "🔮", [14] = "☠️", [15] = "✨", [16] = "🌑",
    [17] = "🛡️"
}

-- Built-in 17-element type counter chart (Attacker -> Defender -> Damage Multiplier)
local TypeCounters = {
    [2] = {[4] = 2.0, [6] = 2.0, [11] = 2.0, [17] = 2.0, [3] = 0.5, [9] = 0.5, [2] = 0.5, [12] = 0.5}, -- Fire counters Grass, Ice, Bug, Steel
    [3] = {[2] = 2.0, [8] = 2.0, [9] = 2.0, [4] = 0.5, [3] = 0.5, [12] = 0.5}, -- Water counters Fire, Ground, Rock
    [4] = {[3] = 2.0, [8] = 2.0, [9] = 2.0, [2] = 0.5, [4] = 0.5, [10] = 0.5, [11] = 0.5, [14] = 0.5, [12] = 0.5, [17] = 0.5}, -- Grass counters Water, Ground, Rock
    [5] = {[3] = 2.0, [10] = 2.0, [5] = 0.5, [4] = 0.5, [12] = 0.5, [8] = 0.0}, -- Electric counters Water, Flying
    [8] = {[2] = 2.0, [5] = 2.0, [14] = 2.0, [9] = 2.0, [17] = 2.0, [4] = 0.5, [11] = 0.5, [10] = 0.0}, -- Ground counters Fire, Electric, Poison, Rock, Steel
    [9] = {[2] = 2.0, [6] = 2.0, [10] = 2.0, [11] = 2.0, [7] = 0.5, [8] = 0.5, [17] = 0.5}, -- Rock counters Fire, Ice, Flying, Bug
    [6] = {[4] = 2.0, [8] = 2.0, [10] = 2.0, [12] = 2.0, [2] = 0.5, [3] = 0.5, [6] = 0.5, [17] = 0.5}, -- Ice counters Grass, Ground, Flying, Dragon
    [7] = {[1] = 2.0, [6] = 2.0, [9] = 2.0, [16] = 2.0, [17] = 2.0, [10] = 0.5, [13] = 0.5, [11] = 0.5, [14] = 0.5}, -- Fighting counters Normal, Ice, Rock, Dark, Steel
    [10] = {[4] = 2.0, [7] = 2.0, [11] = 2.0, [5] = 0.5, [9] = 0.5, [17] = 0.5}, -- Flying counters Grass, Fighting, Bug
    [11] = {[4] = 2.0, [13] = 2.0, [16] = 2.0, [2] = 0.5, [7] = 0.5, [10] = 0.5, [14] = 0.5, [17] = 0.5}, -- Bug counters Grass, Psychic, Dark
    [13] = {[7] = 2.0, [14] = 2.0, [13] = 0.5, [17] = 0.5, [16] = 0.0}, -- Psychic counters Fighting, Poison
    [14] = {[4] = 2.0, [15] = 2.0, [14] = 0.5, [8] = 0.5, [9] = 0.5, [17] = 0.0}, -- Poison counters Grass, Light
    [16] = {[13] = 2.0, [7] = 0.5, [16] = 0.5, [15] = 0.5}, -- Dark counters Psychic
    [12] = {[12] = 2.0, [17] = 0.5, [15] = 0.0}, -- Dragon counters Dragon
    [17] = {[6] = 2.0, [9] = 2.0, [15] = 2.0, [2] = 0.5, [3] = 0.5, [5] = 0.5, [17] = 0.5} -- Steel counters Ice, Rock, Light
}

local function GetElementMultiplier(attackerElem, defenderElem)
    if not attackerElem or not defenderElem then return 1.0 end
    local mult = nil
    pcall(function()
        local etc = ElementTypeConfig or require(ReplicatedStorage.Config.ElementTypeConfig)
        if etc and etc[attackerElem] and etc[attackerElem].counter then
            local val = etc[attackerElem].counter[defenderElem]
            if val then mult = val / 10000 end
        end
    end)
    if mult then return mult end
    if TypeCounters[attackerElem] and TypeCounters[attackerElem][defenderElem] ~= nil then
        return TypeCounters[attackerElem][defenderElem]
    end
    return 1.0
end

local function GetBestCounterElements(defenderElem)
    local counters = {}
    for elemId = 1, 17 do
        local m = GetElementMultiplier(elemId, defenderElem)
        if m >= 2.0 then
            table.insert(counters, elemId)
        end
    end
    return counters
end

local function GetCurrentEnemyInfo()
    local enemyInfo = {
        name = "Unknown Opponent",
        element = 1,
        level = 1,
        hp = 100,
        maxHp = 100
    }
    pcall(function()
        if BattleService and BattleService.getCurrentBattle then
            local cur = BattleService.getCurrentBattle()
            if cur and cur.camp2 and cur.camp2.slots and cur.camp2.slots[1] then
                local slot = cur.camp2.slots[1]
                local cfgId = slot.cfgId or slot.configId or slot.cid or slot.petId
                local petCfg = cfgId and PetConfig and PetConfig[cfgId]
                enemyInfo.name = (petCfg and petCfg.name) or slot.name or slot.petName or ("Opponent_" .. tostring(cfgId or ""))
                enemyInfo.level = tonumber(slot.level) or 1
                enemyInfo.hp = tonumber(slot.hp) or 100
                enemyInfo.maxHp = tonumber(slot.maxHp) or 100
                if petCfg and petCfg.elements and petCfg.elements[1] then
                    enemyInfo.element = petCfg.elements[1]
                elseif slot.element or slot.mainElement then
                    enemyInfo.element = slot.element or slot.mainElement
                end
            end
        end
    end)
    return enemyInfo
end

-- Evaluates all player pets and finds the best counter Evomon against target element
local function SelectBestCounterPetForEnemy(enemyElement)
    if not enemyElement then return nil end
    local bestPet = nil
    local bestScore = -1

    pcall(function()
        local ps = require(ReplicatedStorage.Script.Pet.PetService)
        local code, petData = ps.getPlayerPetData()
        local petList = (type(petData) == "table" and petData.petList) or {}

        for uid, pet in pairs(petList) do
            local cfgId = pet.configId or pet.petId or pet.id
            local petCfg = cfgId and PetConfig and PetConfig[cfgId]
            local elem = (petCfg and petCfg.elements and petCfg.elements[1]) or 1
            local mult = GetElementMultiplier(elem, enemyElement)
            local lvl = tonumber(pet.level) or 1
            local score = (mult * 1000) + lvl
            if score > bestScore then
                bestScore = score
                bestPet = {
                    uid = uid,
                    configId = cfgId,
                    name = (petCfg and petCfg.name) or "Pet",
                    element = elem,
                    level = lvl,
                    multiplier = mult
                }
            end
        end
    end)

    return bestPet
end

-- Automatically equips the best counter Evomon before battle
local function AlignPetCounter(enemyElement)
    if not HubState.SmartCombatAI or not HubState.AutoSwitchPetCounter then return end
    if not enemyElement then return end
    pcall(function()
        local ps = require(ReplicatedStorage.Script.Pet.PetService)
        local curMainUid = ps.getMainPetUid and tostring(ps.getMainPetUid())
        local best = SelectBestCounterPetForEnemy(enemyElement)
        if best and best.uid and tostring(best.uid) ~= curMainUid and best.multiplier >= 1.5 then
            ps.reqSetMainPet(best.uid)
            WindUI:Notify({
                Title = "Smart Pet Counter 🔥",
                Content = string.format("Selected %s (%s) vs %s opponent!", best.name, ElementNames[best.element] or "", ElementNames[enemyElement] or ""),
                Duration = 2.5,
                Icon = "shield"
            })
        end
    end)
end

-- Executes intelligent move selection during combat
local function ExecuteSmartCombatStep()
    local inBattle, battleWin = IsInBattle()
    if not inBattle or not battleWin then return end

    local enemy = GetCurrentEnemyInfo()
    HubState.CurrentEnemyElement = enemy.element
    HubState.CurrentEnemyName = enemy.name

    -- Check if active pet is disadvantaged against current enemy (e.g. Fire vs Water/Fire), and auto-counter switch if needed
    if HubState.AutoSwitchPetCounter and enemy.element then
        pcall(function()
            local ps = require(ReplicatedStorage.Script.Pet.PetService)
            local mainPetUid = ps.getMainPetUid and tostring(ps.getMainPetUid())
            local code, petData = ps.getPlayerPetData()
            local activePet = petData and petData.petList and petData.petList[mainPetUid]
            local activeCfg = activePet and PetConfig and PetConfig[activePet.configId]
            local activeElem = activeCfg and activeCfg.elements and activeCfg.elements[1] or 1
            local currentMult = GetElementMultiplier(activeElem, enemy.element)

            -- If our current pet does not have super-effective advantage (< 1.5x), switch to a counter pet with >= 1.5x advantage
            if currentMult < 1.5 then
                local bestCounter = SelectBestCounterPetForEnemy(enemy.element)
                if bestCounter and bestCounter.uid and tostring(bestCounter.uid) ~= mainPetUid and bestCounter.multiplier >= 1.5 then
                    local MBWC = require(ReplicatedStorage.Controller.MainBattleWindowController)
                    if MBWC and MBWC.applySwitchPet then
                        MBWC.applySwitchPet(bestCounter.uid)
                    end
                    ps.reqSetMainPet(bestCounter.uid)
                end
            end
        end)
    end

    -- 1. Auto Ultimate Burst when charged & ready
    if HubState.AutoCastUltimate and battleWin.UltimateSkillPromptImg and battleWin.UltimateSkillPromptImg.Visible then
        pcall(function()
            if not battleWin._ultimateIsLocked then
                local MBWC = require(ReplicatedStorage.Controller.MainBattleWindowController)
                if MBWC and MBWC.triggerUltimateSkill then
                    MBWC.triggerUltimateSkill()
                end
                for _, c in ipairs(getconnections(battleWin.UltimateSkillPromptImg.MouseButton1Click)) do c:Fire() end
                for _, c in ipairs(getconnections(battleWin.UltimateSkillPromptImg.Activated)) do c:Fire() end
            end
        end)
    end

    -- 2. Smart Move Selection (Highest Damage / Super-Effective 2.0x move)
    if HubState.AutoPickBestMove then
        pcall(function()
            local ps = require(ReplicatedStorage.Script.Pet.PetService)
            local mainPetUid = ps.getMainPetUid and tostring(ps.getMainPetUid())
            local code, petData = ps.getPlayerPetData()
            local activePet = petData and petData.petList and petData.petList[mainPetUid]
            local skills = activePet and activePet.skillList or {}

            if #skills > 0 then
                local bestSlot = 1
                local bestScore = -1
                local bestSkillCfg = nil

                for idx, s in ipairs(skills) do
                    local sCfg = SkillConfig and SkillConfig[s.configId]
                    local power = sCfg and (sCfg.power or sCfg.damage) or 0
                    local isBuff = sCfg and (sCfg.aiType == "PositiveBuff" or power <= 0)

                    -- Filter out pure buffs so damage turns aren't wasted
                    if not isBuff then
                        local elem = sCfg and sCfg.element or 1
                        local mult = GetElementMultiplier(elem, enemy.element)
                        local score = power * mult

                        -- Heavy priority for 2.0x Super-Effective moves (e.g. Cinder vs Grass, Water Gun vs Fire/Rock)
                        if mult >= 2.0 then
                            score = score * 100
                        elseif mult < 1.0 then
                            score = score * 0.1 -- Strongly penalize resisted moves (e.g. Fire move vs Fire enemy)
                        end

                        if score > bestScore then
                            bestScore = score
                            bestSlot = idx
                            bestSkillCfg = sCfg
                        end
                    end
                end

                -- Direct Controller execution of the optimal skill slot
                local MBWC = require(ReplicatedStorage.Controller.MainBattleWindowController)
                if MBWC and MBWC.triggerNormalSkillBySlotIndex then
                    MBWC.triggerNormalSkillBySlotIndex(bestSlot)
                end

                -- GUI fallback: activate skill button via PetNormalSkillScrollView or SkillArea
                if battleWin then
                    local scroll = battleWin.PetNormalSkillScrollView or (battleWin.instance and battleWin.instance:FindFirstChild("PetNormalSkillScrollView", true))
                    if scroll then
                        local count = 0
                        for _, child in ipairs(scroll:GetChildren()) do
                            if child:IsA("GuiObject") and child.Name == "PetSkillItem" then
                                count = count + 1
                                if count == bestSlot then
                                    local btn = child:FindFirstChildWhichIsA("GuiButton", true) or (child:IsA("GuiButton") and child)
                                    if btn then
                                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                    end
                                    break
                                end
                            end
                        end
                    elseif battleWin.instance then
                        local skillArea = battleWin.instance:FindFirstChild("SkillArea", true) or battleWin.instance:FindFirstChild("Skills", true)
                        if skillArea then
                            local btns = {}
                            for _, child in ipairs(skillArea:GetChildren()) do
                                if child:IsA("GuiButton") and child.Visible then
                                    table.insert(btns, child)
                                end
                            end
                            local targetBtn = btns[bestSlot]
                            if targetBtn then
                                for _, c in ipairs(getconnections(targetBtn.MouseButton1Click)) do c:Fire() end
                                for _, c in ipairs(getconnections(targetBtn.Activated)) do c:Fire() end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Trigger Level Breakthrough (breaks Evomon & Player level caps)
local function TriggerLevelBreakthrough()
    local lvRemote = Remote:FindFirstChild("Lv") and Remote.Lv:FindFirstChild("ReqLevelBreakthrough")
    if lvRemote then
        pcall(function()
            lvRemote:InvokeServer()
        end)
    end
end

-- Claim Player Level Rewards
local function TriggerClaimLevelRewards()
    local lrRemote = Remote:FindFirstChild("PlayerLevelReward") and Remote.PlayerLevelReward:FindFirstChild("ReqClaimPlayerLevelReward")
    if lrRemote then
        pcall(function()
            lrRemote:InvokeServer()
        end)
    end
end

-- Dismiss blocking reward, skill & level-up popups so the bot never gets stuck
local function DismissBlockingWindows()
    pcall(function()
        local blockingList = {
            "GetRewardPopUpWindow",
            "LevelRewardsWindow",
            "LevelUPEffectWindow",
            "CommGetRewardTipWindow",
            "CommonRewardClaimWindow",
            "SkillReplaceWindow"
        }
        for _, winName in ipairs(blockingList) do
            if UIManager:isOpen(winName) then
                UIManager:close(winName)
            end
        end
    end)
end

-- Scan wild creatures
local function FetchWildCreatures()
    local now = os.clock()
    if (now - HubState.LastCreatureScan) < 2.5 and #HubState.CachedCreatures > 0 then
        return HubState.CachedCreatures
    end

    local remote = Remote:FindFirstChild("Creature") and Remote.Creature:FindFirstChild("ReqGetAllCreatures")
    if not remote then return {} end

    local ok, res = pcall(function() return remote:InvokeServer() end)
    if not ok or type(res) ~= "table" then return {} end

    HubState.LastCreatureScan = now
    local list = {}
    local root = GetRootPart()
    local rootPos = root and root.Position or Vector3.zero

    for uid, data in pairs(res) do
        if data.pos and typeof(data.pos) == "CFrame" and data.aliveState == 1 then
            local cfgId = tonumber(data.configId)
            local petInfo = cfgId and PetConfig and PetConfig[cfgId]
            local dist = (data.pos.Position - rootPos).Magnitude

            table.insert(list, {
                uid = tostring(uid),
                cfgId = cfgId,
                name = petInfo and petInfo.name or ("Evomon_" .. tostring(cfgId)),
                level = tonumber(data.level) or 1,
                cframe = data.pos,
                position = data.pos.Position,
                distance = dist
            })
        end
    end

    table.sort(list, function(a, b) return a.distance < b.distance end)
    HubState.CachedCreatures = list
    HubState.ClosestEvomon = list[1]
    return list
end

-- Get creatures near a specific position (e.g. Island center)
local function GetCreaturesNearPos(targetPos, maxRadius)
    local all = FetchWildCreatures()
    local nearby = {}
    for _, c in ipairs(all) do
        local d = (c.position - targetPos).Magnitude
        if d <= maxRadius then
            local clone = table.clone(c)
            clone.islandDistance = d
            table.insert(nearby, clone)
        end
    end
    table.sort(nearby, function(a, b) return a.islandDistance < b.islandDistance end)
    return nearby
end

-- ====================
-- AUTO QUEST CONTROLLER
-- ====================

local function GetCurrentQuestInfo()
    local tc = nil
    pcall(function()
        tc = require(ReplicatedStorage.Controller.TaskController)
    end)
    local taskDerived = tc and tc.getAcceptedMainTaskDerivedData and tc.getAcceptedMainTaskDerivedData()
    local taskService = nil
    pcall(function()
        taskService = require(ReplicatedStorage.Script.Task.TaskService)
    end)
    local mainTask = nil
    if taskService and taskService.getCurrMainTask then
        local code, task = taskService.getCurrMainTask()
        if code == 20000 and task then
            mainTask = task
        end
    end

    local taskId = (taskDerived and taskDerived.taskId) or (mainTask and mainTask.id) or 1001
    local taskName = (taskDerived and taskDerived.taskName) or (mainTask and mainTask.taskTitle) or "No Active Quest"
    local progressText = (taskDerived and taskDerived.progressText) or ""
    local isClaimable = (taskDerived and taskDerived.isClaimable) or false
    local isCompleted = (taskDerived and taskDerived.isCompleted) or false

    -- Universal Screen HUD Quest Reader (Deep Scan across PlayerGui)
    pcall(function()
        local lp = LocalPlayer
        local pgui = lp and lp:FindFirstChild("PlayerGui")
        if pgui then
            for _, gui in ipairs(pgui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "WindUI" then
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible and desc.Text ~= "" then
                            local txt = desc.Text
                            local pMatch = txt:match("%((%d+/%d+)%)")
                            if pMatch or string.find(txt, "Defeat") or string.find(txt, "Catch") or string.find(txt, "King") or string.find(txt, "Pebgolem") or string.find(txt, "Reach") or string.find(txt, "Feed") or string.find(txt, "Evolve") or string.find(txt, "Talk") then
                                if pMatch and progressText == "" then
                                    progressText = pMatch
                                end
                                if taskName == "No Active Quest" or string.find(taskName, "Task") or taskName == "" or string.find(txt, "King") or string.find(txt, "Defeat") then
                                    local cleaned = txt:gsub("%s*%(%d+/%d+%)%s*$", "")
                                    cleaned = cleaned:gsub("%%c+", " "):gsub("%%s+", " ")
                                    taskName = cleaned
                                end
                                if pMatch then
                                    local cur, max = pMatch:match("(%d+)/(%d+)")
                                    if cur and max and tonumber(cur) >= tonumber(max) and tonumber(max) > 0 then
                                        isCompleted = true
                                        isClaimable = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    local goalInfo = nil
    pcall(function()
        local gCfg = GoalConfig or require(ReplicatedStorage.Config.GoalConfig)
        if mainTask and mainTask.goals and mainTask.goals[1] and mainTask.goals[1][1] then
            local goalId = mainTask.goals[1][1]
            goalInfo = gCfg[goalId]
        elseif taskId and gCfg[taskId] then
            goalInfo = gCfg[taskId]
        end
    end)

    -- Detect target Island from quest name (e.g. "Verdant Valley" -> Island 1, "Amber Acres" -> Island 4)
    local targetIsland = nil
    for _, isl in ipairs(IslandData) do
        local cleanName = isl.name:match("%((.+)%)") or isl.name
        if string.find(taskName:lower(), cleanName:lower()) then
            targetIsland = isl
            break
        end
    end

    -- Intelligent Quest Category Classifier (Config Data Priority)
    local taskLower = taskName:lower()
    local gType = goalInfo and goalInfo.type
    local isBossTask = false
    local bossName = nil
    local isCatchTask = false
    local isLevelTask = false
    local isDialogueTask = false
    local isArriveTask = false
    local isFeedTask = false
    local isEvolveTask = false
    local targetNpcName = nil
    local targetCreatureName = nil

    -- Check if it's explicitly a Catch task (Goal type 5 or title includes Catch)
    if gType == 5 or string.find(taskLower, "catch") or string.find(taskLower, "capture") then
        isCatchTask = true
        targetCreatureName = taskName:match("Catch%s+%d*%s*([%a%s]+)%s+in") or taskName:match("Catch%s+a%s+([%a%s]+)%s+in") or taskName:match("Catch%s+([%a%s]+)")
        if targetCreatureName then targetCreatureName = targetCreatureName:gsub("^%s*(.-)%s*$", "%1") end
    elseif gType == 10 or string.find(taskLower, "talk") or string.find(taskLower, "speak") or string.find(taskLower, "meet") then
        isDialogueTask = true
        targetNpcName = taskName:match("Talk%s+to%s+([%a%s]+)") or taskName:match("Speak%s+with%s+([%a%s]+)")
        if targetNpcName then targetNpcName = targetNpcName:gsub("^%s*(.-)%s*$", "%1") end
    elseif gType == 34 or string.find(taskLower, "feed") then
        isFeedTask = true
    elseif gType == 41 or string.find(taskLower, "arrive") or string.find(taskLower, "travel") or string.find(taskLower, "explore") then
        isArriveTask = true
    elseif gType == 42 or string.find(taskLower, "evolve") or string.find(taskLower, "evolution") or string.find(taskLower, "breakthrough") then
        isEvolveTask = true
    elseif gType == 40 or gType == 8 or string.find(taskLower, "level") or string.find(taskLower, "reach") or string.find(taskLower, "lv") then
        isLevelTask = true
    elseif string.find(taskLower, "pebgolem") or (string.find(taskLower, "king") and not isCatchTask) or string.find(taskLower, "boss") then
        isBossTask = true
        bossName = taskName:match("Defeat%s+the%s+([%a%s]+)%s+in") or taskName:match("Defeat%s+([%a%s]+)%s+in") or taskName:match("([%a%s]+)%s+in") or "Boss"
        bossName = bossName:gsub("^%s*(.-)%s*$", "%1")
    elseif gType == 22 or gType == 39 or string.find(taskLower, "defeat") or string.find(taskLower, "beat") or string.find(taskLower, "battle") then
        targetNpcName = taskName:match("Defeat%s+([%a%s]+)%s+in") or taskName:match("Defeat%s+([%a%s]+)")
        if targetNpcName then targetNpcName = targetNpcName:gsub("^%s*(.-)%s*$", "%1") end
    end

    HubState.CurrentQuestObjective = taskName
    HubState.CurrentQuestIsland = targetIsland and targetIsland.name or "Current"

    return {
        taskId = taskId,
        name = taskName,
        progress = progressText,
        isClaimable = isClaimable,
        isCompleted = isCompleted,
        mainTask = mainTask,
        taskDerived = taskDerived,
        goal = goalInfo,
        targetIsland = targetIsland,
        isBossTask = isBossTask,
        bossName = bossName,
        isCatchTask = isCatchTask,
        isLevelTask = isLevelTask,
        isDialogueTask = isDialogueTask,
        isArriveTask = isArriveTask,
        isFeedTask = isFeedTask,
        isEvolveTask = isEvolveTask,
        targetNpcName = targetNpcName,
        targetCreatureName = targetCreatureName
    }
end

-- Fully executes whatever the active quest requires
local function ExecuteQuestStep()
    if IsInBattle() then return end
    DismissBlockingWindows()

    local quest = GetCurrentQuestInfo()
    if not quest or not quest.taskId then return end

    -- Step 1: Instant Auto-Claim if quest is complete
    if quest.isClaimable or quest.isCompleted then
        pcall(function()
            Remote.Task.ReqCompleteTask:InvokeServer(quest.taskId)
        end)
        pcall(function()
            local tc = require(ReplicatedStorage.Controller.TaskController)
            if tc and tc.claimTask then tc.claimTask(quest.taskId) end
        end)
        pcall(function()
            local ts = require(ReplicatedStorage.Script.Task.TaskService)
            if ts and ts.reqCompleteTask then ts.reqCompleteTask(quest.taskId) end
        end)
        DismissBlockingWindows()
        WindUI:Notify({
            Title = "Quest Completed!",
            Content = "Claimed " .. quest.name .. "!",
            Duration = 3,
            Icon = "check"
        })
        return
    end

    local gType = quest.goal and quest.goal.type
    local gParams = quest.goal and quest.goal.params
    local allCreatures = FetchWildCreatures()

    -- ========================================================
    -- QUEST TYPE 1: BOSS / KING ELIMINATION (Only when not a catch/wild objective)
    -- ========================================================
    if (quest.isBossTask or (quest.name and string.find(quest.name:lower(), "pebgolem"))) and not quest.isCatchTask and gType ~= 5 and gType ~= 4 then
        local bossTarget = nil
        local searchName = quest.bossName or "Pebgolem"
        local searchLower = searchName:lower()

        -- 1a. Search in wild creatures list
        for _, c in ipairs(allCreatures) do
            if string.find(c.name:lower(), searchLower) or (string.find(c.name:lower(), "king") and string.find(c.name:lower(), "pebgolem")) then
                bossTarget = c
                break
            end
        end

        -- 1b. Search workspace models recursively
        if not bossTarget then
            local function ScanFolderForBoss(parent)
                if not parent or bossTarget then return end
                for _, obj in ipairs(parent:GetChildren()) do
                    if obj:IsA("Model") then
                        local mName = obj.Name:lower()
                        if string.find(mName, "pebgolem") or string.find(mName, "king") or (string.find(mName, "boss") and (string.find(mName, "1") or string.find(mName, "peb"))) then
                            local root = obj:FindFirstChild("HumanoidRootPart", true) or obj:FindFirstChildWhichIsA("BasePart", true)
                            if root then
                                bossTarget = {
                                    uid = obj.Name,
                                    cframe = root.CFrame,
                                    position = root.Position,
                                    name = obj.Name,
                                    modelInstance = obj
                                }
                                return
                            end
                        end
                    end
                end
            end

            ScanFolderForBoss(workspace:FindFirstChild("Scene"))
            ScanFolderForBoss(workspace:FindFirstChild("RuntimeCache"))
            ScanFolderForBoss(workspace:FindFirstChild("Monsters"))
            ScanFolderForBoss(workspace:FindFirstChild("NPC"))
            ScanFolderForBoss(workspace)
        end

        -- 1c. Deep Descendants Scan for Pebgolem / King Model in Workspace
        if not bossTarget then
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                        local mName = obj.Name:lower()
                        if string.find(mName, "pebgolem") or string.find(mName, "king") or (string.find(mName, "boss") and string.find(mName, "peb")) then
                            local root = obj:FindFirstChild("HumanoidRootPart", true) or obj:FindFirstChildWhichIsA("BasePart", true)
                            if root then
                                bossTarget = {
                                    uid = obj.Name,
                                    cframe = root.CFrame,
                                    position = root.Position,
                                    name = obj.Name,
                                    modelInstance = obj
                                }
                                break
                            end
                        end
                    end
                end
            end)
        end

        -- 1d. Giant Model Proximity Detection fallback (Massive boss model within 450 studs)
        if not bossTarget then
            local myRoot = GetRootPart()
            if myRoot then
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                        local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                        if root and (root.Position - myRoot.Position).Magnitude <= 450 then
                            local size = obj:GetExtentsSize()
                            if size.Y >= 9 or size.X >= 9 or size.Z >= 9 then
                                bossTarget = {
                                    uid = obj.Name,
                                    cframe = root.CFrame,
                                    position = root.Position,
                                    name = obj.Name,
                                    modelInstance = obj
                                }
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Walk to Boss & Initiate Combat
        if bossTarget then
            if HubState.SmartCombatAI and HubState.AutoSwitchPetCounter then
                AlignPetCounter(9) -- Counter Rock / Ground
            end

            SafeMoveTo(bossTarget.cframe, 10, 20)
            task.wait(HubState.PostTpDelay or 0.3)

            if not IsInBattle() then
                -- Method 1: Fire all proximity prompts on boss
                pcall(function()
                    local m = bossTarget.modelInstance or (bossTarget.uid and workspace:FindFirstChild(tostring(bossTarget.uid), true))
                    if m then
                        for _, prompt in ipairs(m:GetDescendants()) do
                            if prompt:IsA("ProximityPrompt") then
                                prompt.HoldDuration = 0
                                prompt.RequiresLineOfSight = false
                                -- fireproximityprompt removed for detection safety
                                for _, c in ipairs(getconnections(prompt.Triggered)) do c:Fire() end
                                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do c:Fire() end
                            end
                        end
                    end
                end)
                -- Method 2: Official BattleService enterPetBattle
                pcall(function()
                    if BattleService and BattleService.enterPetBattle then
                        BattleService.enterPetBattle(tostring(bossTarget.uid))
                    end
                end)
                -- Method 3: Official enterActualNpcBattle
                pcall(function()
                    if BattleService and BattleService.enterActualNpcBattle then
                        local ps = require(ReplicatedStorage.Script.Pet.PetService)
                        local mainPet = ps and ps.getMainPetUid and tostring(ps.getMainPetUid())
                        if mainPet then
                            BattleService.enterActualNpcBattle(1001, 11000001, mainPet)
                        end
                    end
                end)
                -- Method 4: Server Remotes
                pcall(function()
                    if Remote and Remote:FindFirstChild("Battle") and Remote.Battle:FindFirstChild("ReqEnterNpcBattle") then
                        Remote.Battle.ReqEnterNpcBattle:FireServer(1001, 11000001)
                    end
                end)
                pcall(function()
                    if BattleService and BattleService.reportEnterBossBattle then
                        BattleService.reportEnterBossBattle(1)
                    end
                end)
            end
            return
        else
            -- Navigate towards Boss Island if on wrong island (Defaults to Island 1 Verdant Valley for Pebgolem King)
            local targetPos = (quest.targetIsland and quest.targetIsland.pos) or IslandData[1].pos
            local myPos = GetRootPart() and GetRootPart().Position or Vector3.zero
            local distToIsland = (myPos - targetPos).Magnitude
            if distToIsland > 250 then
                SafeMoveTo(targetPos, 15, 30)
                return
            end
        end
    end

    -- ========================================================
    -- QUEST TYPE 2: CATCH / DEFEAT SPECIFIC OR WILD EVOMON (Goal 4, 5 or Catch Directive)
    -- ========================================================
    if gType == 4 or gType == 5 or quest.isCatchTask or string.find(quest.name:lower(), "defeat wild") then
        local targetCfgId = gParams and gParams[1]
        local targetCreature = nil

        if targetCfgId then
            for _, c in ipairs(allCreatures) do
                if c.cfgId == targetCfgId then
                    targetCreature = c
                    break
                end
            end
        end

        if not targetCreature and quest.targetCreatureName then
            for _, c in ipairs(allCreatures) do
                if string.find(c.name:lower(), quest.targetCreatureName:lower()) then
                    targetCreature = c
                    break
                end
            end
        end

        if not targetCreature then
            for _, c in ipairs(allCreatures) do
                if string.find(quest.name:lower(), c.name:lower()) then
                    targetCreature = c
                    break
                end
            end
        end

        -- Only fallback to generic wild creatures if the quest has NO specific target species
        if not targetCreature and (not targetCfgId and not quest.targetCreatureName) and #allCreatures > 0 then
            targetCreature = allCreatures[1]
        end

        if targetCreature then
            if HubState.SmartCombatAI and HubState.AutoSwitchPetCounter and targetCreature.cfgId then
                local petCfg = PetConfig and PetConfig[targetCreature.cfgId]
                if petCfg and petCfg.mainElement then
                    AlignPetCounter(petCfg.mainElement)
                end
            end
            SafeMoveTo(targetCreature.cframe, 8, 15)
            task.delay(0.2, function()
                if not IsInBattle() and BattleService and BattleService.enterPetBattle then
                    pcall(function()
                        BattleService.enterPetBattle(tostring(targetCreature.uid))
                    end)
                end
            end)
            return
        else
            -- Walk towards target island if needed
            if quest.targetIsland and HubState.AutoNavigateToQuestIsland then
                SafeMoveTo(quest.targetIsland.pos, 15, 30)
                return
            end
        end

    -- ========================================================
    -- QUEST TYPE 3: TRAINER / NPC BATTLE (Goal 22, 39 or Defeat NPC Directive)
    -- ========================================================
    elseif gType == 22 or gType == 39 or (quest.targetNpcName and not quest.isDialogueTask) then
        local battlePoolId = gParams and gParams[1]
        local trainerId = nil
        local trainerName = quest.targetNpcName
        local trainerModel = nil

        pcall(function()
            local bpConfig = BattlePoolConfig or (Config and require(Config:FindFirstChild("BattlePoolConfig")))
            if bpConfig and battlePoolId and bpConfig[battlePoolId] then
                local bp = bpConfig[battlePoolId]
                if bp.positionTrainers and #bp.positionTrainers > 0 then
                    trainerId = bp.positionTrainers[1]
                end
            end
        end)

        if not trainerId and battlePoolId and battlePoolId < 100000 then
            trainerId = battlePoolId
        end

        pcall(function()
            local trConfig = BattleTrainerConfig or (Config and require(Config:FindFirstChild("BattleTrainerConfig")))
            if trConfig and trainerId and trConfig[trainerId] then
                local tr = trConfig[trainerId]
                trainerName = tr.name or trainerName
                trainerModel = tr.model
            end
        end)

        local targetNPC = nil
        if trainerId or trainerName then
            for _, c in ipairs(allCreatures) do
                local match = false
                if trainerId and (c.cfgId == trainerId or tostring(c.uid) == tostring(trainerId)) then
                    match = true
                elseif trainerName and string.find(c.name:lower(), trainerName:lower()) then
                    match = true
                end
                if match then
                    targetNPC = c
                    break
                end
            end
        end

        if not targetNPC then
            pcall(function()
                local cache = workspace:FindFirstChild("RuntimeCache")
                if cache then cache = cache:FindFirstChild("RuntimeCacheServer") end
                if cache then cache = cache:FindFirstChild("CreatureModelCache") end
                if cache then
                    for _, model in ipairs(cache:GetChildren()) do
                        local isMatch = false
                        if model.Name == tostring(trainerId) then isMatch = true end
                        if trainerModel and (model.Name == trainerModel or model:FindFirstChild(trainerModel)) then isMatch = true end
                        if trainerName and string.find(model.Name:lower(), trainerName:lower()) then isMatch = true end
                        if isMatch then
                            local root = model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChildWhichIsA("BasePart", true)
                            if root then
                                targetNPC = {
                                    uid = model.Name,
                                    cframe = root.CFrame,
                                    name = trainerName or model.Name,
                                    modelInstance = model
                                }
                                break
                            end
                        end
                    end
                end
            end)
        end

        if targetNPC and targetNPC.cframe then
            SafeMoveTo(targetNPC.cframe + Vector3.new(0, 0, 3.5), 8, 15)
            task.delay(0.25, function()
                if IsInBattle() then return end
                local mainPetUid = nil
                pcall(function()
                    local ps = require(ReplicatedStorage.Script.Pet.PetService)
                    if ps and ps.getMainPetUid then mainPetUid = tostring(ps.getMainPetUid()) end
                end)

                local realTrainerId = trainerId or 1004
                local bId = tonumber(battlePoolId) or 11000004
                local modelUid = tonumber(targetNPC.uid)

                pcall(function()
                    if BattleService and BattleService.enterActualNpcBattle and mainPetUid then
                        BattleService.enterActualNpcBattle(realTrainerId, bId, mainPetUid)
                    end
                end)
                pcall(function()
                    if BattleService and BattleService.enterNpcBattle then
                        BattleService.enterNpcBattle(realTrainerId, bId)
                        if modelUid then
                            BattleService.enterNpcBattle(modelUid, bId)
                        end
                    end
                end)
                pcall(function()
                    if Remote and Remote:FindFirstChild("Battle") and Remote.Battle:FindFirstChild("ReqEnterNpcBattle") then
                        if mainPetUid then
                            Remote.Battle.ReqEnterNpcBattle:FireServer(realTrainerId, bId, mainPetUid)
                        end
                        Remote.Battle.ReqEnterNpcBattle:FireServer(realTrainerId, bId)
                    end
                end)
            end)
            return
        else
            if quest.targetIsland and HubState.AutoNavigateToQuestIsland then
                SafeMoveTo(quest.targetIsland.pos, 15, 30)
                return
            end
        end

    -- ========================================================
    -- QUEST TYPE 4: TALK TO NPC / DIALOGUE (Goal 10 or Dialogue Directive)
    -- ========================================================
    elseif gType == 10 or quest.isDialogueTask then
        local npcId = gParams and gParams[1]
        local npcTarget = nil
        local npcName = quest.targetNpcName

        -- Search for NPC model in workspace
        pcall(function()
            local npcFolder = workspace:FindFirstChild("NPC") or workspace:FindFirstChild("Scene")
            if npcFolder then
                for _, m in ipairs(npcFolder:GetDescendants()) do
                    if m:IsA("Model") and (m.Name == tostring(npcId) or (npcName and string.find(m.Name:lower(), npcName:lower()))) then
                        local root = m:FindFirstChild("HumanoidRootPart", true) or m:FindFirstChildWhichIsA("BasePart", true)
                        if root then
                            npcTarget = { model = m, cframe = root.CFrame }
                            break
                        end
                    end
                end
            end
        end)

        if npcTarget and npcTarget.cframe then
            SafeMoveTo(npcTarget.cframe, 8, 15)
            pcall(function()
                for _, p in ipairs(npcTarget.model:GetDescendants()) do
                    if p:IsA("ProximityPrompt") then
                        p.HoldDuration = 0
                        p.RequiresLineOfSight = false
                        -- fireproximityprompt removed for detection safety
                        for _, c in ipairs(getconnections(p.Triggered)) do c:Fire() end
                    end
                end
            end)
        end

        if npcId then
            pcall(function()
                if Remote:FindFirstChild("Dialogue") then
                    if Remote.Dialogue:FindFirstChild("ReqReceiveDialogueTask") then
                        Remote.Dialogue.ReqReceiveDialogueTask:InvokeServer(npcId)
                    end
                    if Remote.Dialogue:FindFirstChild("ReqMarkDialogueTalkCompleted") then
                        Remote.Dialogue.ReqMarkDialogueTalkCompleted:FireServer(npcId)
                    end
                    if Remote.Dialogue:FindFirstChild("ReqCompleteDialogueTask") then
                        Remote.Dialogue.ReqCompleteDialogueTask:InvokeServer(npcId)
                    end
                end
            end)
        end
        return

    -- ========================================================
    -- QUEST TYPE 5: LEVEL UP / REACH LEVEL (Goal 40, 8 or Level Directive)
    -- ========================================================
    elseif gType == 40 or gType == 8 or quest.isLevelTask then
        local targetLevel = (gParams and gParams[1]) or 55
        TriggerLevelBreakthrough()

        -- Auto-feed EXP items
        pcall(function()
            local ps = require(ReplicatedStorage.Script.Pet.PetService)
            local BagService = require(ReplicatedStorage.Script.Bag.BagService)
            local mainPet = ps.getMainPetUid()
            local fruitIds = {4000039, 4000023, 4000022, 4000021}
            for _, fId in ipairs(fruitIds) do
                local count = BagService.getItemNumById and BagService.getItemNumById(fId)
                if count and count > 0 then
                    ps.reqPetAddExpByItems(mainPet, {{id = fId, num = 1}})
                    break
                end
            end
        end)

        -- Fight wild Evomons to grind EXP
        if #allCreatures > 0 then
            local bestTarget = allCreatures[1]
            for _, c in ipairs(allCreatures) do
                if c.level >= targetLevel then
                    bestTarget = c
                    break
                end
            end
            SafeMoveTo(bestTarget.cframe, 8, 15)
            task.delay(0.2, function()
                if not IsInBattle() and BattleService and BattleService.enterPetBattle then
                    pcall(function() BattleService.enterPetBattle(tostring(bestTarget.uid)) end)
                end
            end)
            return
        end

    -- ========================================================
    -- QUEST TYPE 6: FEED EVOMON (Goal 34 or Feed Directive)
    -- ========================================================
    elseif gType == 34 or quest.isFeedTask then
        pcall(function()
            local ps = require(ReplicatedStorage.Script.Pet.PetService)
            local mainPet = ps.getMainPetUid()
            if mainPet then
                ps.reqPetAddExpByItems(mainPet, {{id = 4000022, num = 1}})
                ps.reqPetInteraction(mainPet, 1)
            end
        end)
        return

    -- ========================================================
    -- QUEST TYPE 7: ARRIVE AT ISLAND / EXPLORATION (Goal 41 or Arrive Directive)
    -- ========================================================
    elseif gType == 41 or quest.isArriveTask then
        local islandId = gParams and gParams[1]
        local targetPos = nil
        if islandId and IslandData[islandId] then
            targetPos = IslandData[islandId].pos
        elseif quest.targetIsland then
            targetPos = quest.targetIsland.pos
        end

        if targetPos then
            SafeMoveTo(targetPos, 12, 30)
            return
        end

    -- ========================================================
    -- QUEST TYPE 8: EVOLVE / BREAKTHROUGH (Goal 42 or Evolve Directive)
    -- ========================================================
    elseif gType == 42 or quest.isEvolveTask then
        TriggerLevelBreakthrough()
        pcall(function()
            local ps = require(ReplicatedStorage.Script.Pet.PetService)
            local mainPet = ps.getMainPetUid()
            if mainPet and ps.reqPetEvolution then
                ps.reqPetEvolution(mainPet)
            end
        end)
        return
    end

    -- ========================================================
    -- UNIVERSAL FALLBACK: Walk towards closest creature or trigger Guide
    -- ========================================================
    if #allCreatures > 0 then
        local target = allCreatures[1]
        SafeMoveTo(target.cframe, 8, 15)
        task.delay(0.2, function()
            if not IsInBattle() and BattleService and BattleService.enterPetBattle then
                pcall(function()
                    BattleService.enterPetBattle(tostring(target.uid))
                end)
            end
        end)
        return
    end

    -- In-game Quest Guide Click
    pcall(function()
        local open = UIManager:getOpenedUIWindowList()
        for _, w in ipairs(open or {}) do
            if w.name == "MainWindow" and w.QuestButton then
                for _, c in ipairs(getconnections(w.QuestButton.MouseButton1Click)) do c:Fire() end
                break
            end
        end
    end)
end

local ActiveCodes = {
    "EVOS3MIDUPDATE",
    "EVOMONSEASON3",
    "Wmidseason",
    "SEASON2GO",
    "240evoRISE",
    "100DCUNITY",
    "EVO120HYPE",
    "D50CREW",
    "EVO60SPARK",
    "SeasonComing",
    "20KMEMBERS",
    "30K-LIKES",
    "20000LIKES",
    "YTBgift",
    "FORGROUP",
    "12klikeS",
    "10KCCU_",
    "10kthx",
    "5000DC",
    "THXFOR5K",
    "2K-LIKES"
}

-- Redeem a code
local function RedeemCode(code)
    local remote = Remote:FindFirstChild("GiftCode") and Remote.GiftCode:FindFirstChild("ReqRedeemGiftCode")
    if remote then
        local ok, res = pcall(function() return remote:InvokeServer(code) end)
        return ok and res or 0
    end
    return 0
end

-- Redeem all codes
local function RedeemAllCodes()
    local successCount = 0
    for _, code in ipairs(ActiveCodes) do
        local res = RedeemCode(code)
        if res == 20000 then
            successCount = successCount + 1
        end
        task.wait(0.2)
    end
    return successCount
end

-- Claim all mail
local function ClaimMail()
    local remote = Remote:FindFirstChild("Mail") and Remote.Mail:FindFirstChild("ReqClaimAllMailReward")
    if remote then
        local ok, res = pcall(function() return remote:InvokeServer() end)
        return ok and res == 20000
    end
    return false
end

-- Claim daily
local function ClaimDaily()
    local dr = Remote:FindFirstChild("DailyReward")
    local remote = dr and (dr:FindFirstChild("ReqClaimDailyReward") or dr:FindFirstChild("ClaimDailyReward"))
    if remote then
        local ok, res = pcall(function() return remote:InvokeServer(1) end)
        return ok and res == 20000
    end
    return false
end

-- Claim group reward
local function ClaimGroup()
    local gr = Remote:FindFirstChild("GroupReward") and Remote.GroupReward:FindFirstChild("ReqApplyGroupReward")
    if gr then
        local ok, res = pcall(function() return gr:InvokeServer() end)
        return ok and res == 20000
    end
    return false
end

-- ====================
-- UI TABS SETUP
-- ====================

local TabQuest = Window:Tab({
    Title = "Auto Quest & Story",
    Icon = "scroll",
})

local TabIslandFarm = Window:Tab({
    Title = "Island Auto Farm",
    Icon = "swords",
})

local TabRadar = Window:Tab({
    Title = "Wild Evomons & ESP",
    Icon = "compass",
})

local TabRewards = Window:Tab({
    Title = "Auto Rewards & Codes",
    Icon = "gift",
})

local TabTeleports = Window:Tab({
    Title = "World Teleports",
    Icon = "map-pin",
})

local TabPlayer = Window:Tab({
    Title = "Player & Misc",
    Icon = "user",
})

-- ===================================================
-- TAB 1: AUTO QUEST & STORYLINE COMPLETER
-- ===================================================

TabQuest:Section({ Title = "Live Story & Quest Tracker" })

local QuestStatusPara = TabQuest:Paragraph({
    Title = "Current Active Quest",
    Desc = "Scanning current quest from game..."
})

TabQuest:Section({ Title = "Autonomous Quest Solver" })

TabQuest:Toggle({
    Title = "Enable Auto Quest (Follows Any Quest)",
    Desc = "Reads your active quest, walks directly to objectives/monsters, engages battles, talks to NPCs, feeds Evomons, claims rewards, and advances continuously!",
    Value = false,
    Callback = function(state)
        HubState.AutoQuest = state
        if state then
            HubState.IsNavigating = false
            WindUI:Notify({
                Title = "Auto Quest Active!",
                Content = "Solving current quest: " .. tostring(HubState.CurrentQuestObjective or "Scanning..."),
                Duration = 3,
                Icon = "play"
            })
            task.spawn(function()
                ExecuteQuestStep()
            end)
        else
            HubState.IsNavigating = false
            local hum = GetHumanoid()
            if hum then hum:Move(Vector3.zero) end
            WindUI:Notify({
                Title = "Auto Quest Stopped",
                Content = "Auto quest paused.",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

TabQuest:Toggle({
    Title = "Auto Claim Completed Quests",
    Desc = "Automatically turns in completed quests and accepts the next storyline quest",
    Value = true,
    Callback = function(state)
        HubState.AutoQuestClaim = state
    end
})

TabQuest:Toggle({
    Title = "Auto Defeat Island Bosses & Kings",
    Desc = "Detects boss/king objectives (e.g. Pebgolem King, Island Bosses), paths directly to their arena, and initiates combat",
    Value = true,
    Callback = function(state)
        HubState.AutoChallengeBoss = state
    end
})

TabQuest:Toggle({
    Title = "Auto Island Travel for Quests",
    Desc = "Automatically navigates to whichever island your active quest requires (e.g. Verdant Valley, Lava Crag)",
    Value = true,
    Callback = function(state)
        HubState.AutoNavigateToQuestIsland = state
    end
})

TabQuest:Slider({
    Title = "Quest Action Interval",
    Desc = "Time in seconds between automated quest step actions",
    Value = { Min = 1.5, Max = 8, Default = 3 },
    Step = 0.5,
    Callback = function(val)
        HubState.QuestStepDelay = val
    end
})

TabQuest:Section({ Title = "Manual Quest Actions" })

TabQuest:Button({
    Title = "Do Quest Step Now",
    Desc = "Forces the bot to perform the next quest action immediately",
    Callback = function()
        task.spawn(ExecuteQuestStep)
        WindUI:Notify({ Title = "Executing Quest", Content = "Processing active quest step...", Duration = 2, Icon = "zap" })
    end
})

TabQuest:Button({
    Title = "Claim Current Quest Rewards",
    Desc = "Manually triggers ReqCompleteTask for your current quest",
    Callback = function()
        local q = GetCurrentQuestInfo()
        if q and q.taskId then
            local res = nil
            pcall(function()
                res = Remote.Task.ReqCompleteTask:InvokeServer(q.taskId)
            end)
            DismissBlockingWindows()
            WindUI:Notify({
                Title = "Quest Claim Result",
                Content = "Response: " .. tostring(res or "Sent"),
                Duration = 3,
                Icon = "gift"
            })
        end
    end
})

TabQuest:Button({
    Title = "Click In-Game Quest Guide",
    Desc = "Triggers the in-game HUD quest guide button (MainWindow.QuestButton)",
    Callback = function()
        pcall(function()
            local open = UIManager:getOpenedUIWindowList()
            for _, w in ipairs(open or {}) do
                if w.name == "MainWindow" and w.QuestButton then
                    local conns = getconnections(w.QuestButton.MouseButton1Click)
                    for _, c in ipairs(conns) do
                        c:Fire()
                    end
                    break
                end
            end
        end)
        WindUI:Notify({ Title = "Quest Guide Clicked", Content = "Triggered game quest guide.", Duration = 2, Icon = "compass" })
    end
})

-- ===================================================
-- TAB 2: ISLAND PROGRESSION AUTO FARM & BOSS KILLER
-- ===================================================

TabIslandFarm:Section({ Title = "Progression Auto Farm" })

local FarmStatusPara = TabIslandFarm:Paragraph({
    Title = "Island Progression Status",
    Desc = "Status: Idle\nCurrent Target: Island 1 (Verdant Valley)\nProgress: 0 / 5 Evomons"
})

TabIslandFarm:Toggle({
    Title = "Enable Island Progression Farm",
    Desc = "Teleports to wild Evomons -> engages battle -> advances to next island -> repeats -> kills Boss!",
    Value = false,
    Callback = function(state)
        HubState.IslandAutoFarm = state
        if state then
            HubState.FarmsOnCurrentIsland = 0
            local current = IslandData[HubState.CurrentIslandIndex]
            if current then
                TeleportTo(current.pos)
            end
            WindUI:Notify({
                Title = "Island Farm Started!",
                Content = string.format("Farming %s! (Advance every %d Evomons)", current and current.name or "Island", HubState.FarmsPerIsland),
                Duration = 3,
                Icon = "play"
            })
        else
            WindUI:Notify({
                Title = "Island Farm Stopped",
                Content = "Auto farm disabled.",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

TabIslandFarm:Slider({
    Title = "Evomons To Farm Per Island",
    Desc = "How many wild Evomons to defeat before advancing to the next island",
    Value = { Min = 1, Max = 25, Default = 5 },
    Step = 1,
    Callback = function(val)
        HubState.FarmsPerIsland = val
    end
})

-- Build island name list for dropdown
local IslandNames = {}
for i, isl in ipairs(IslandData) do
    table.insert(IslandNames, isl.name)
end

TabIslandFarm:Dropdown({
    Title = "Starting / Target Island",
    Desc = "Choose which island to start or focus farming on",
    Values = IslandNames,
    Value = IslandNames[1],
    Callback = function(selected)
        for idx, isl in ipairs(IslandData) do
            if isl.name == selected then
                HubState.CurrentIslandIndex = idx
                HubState.FarmsOnCurrentIsland = 0
                if HubState.IslandAutoFarm then
                    TeleportTo(isl.pos)
                end
                break
            end
        end
    end
})

TabIslandFarm:Section({ Title = "Smart Elemental Battle AI (Counters & Move Optimizer)" })

local CombatAIPara = TabIslandFarm:Paragraph({
    Title = "Smart Elemental Battle AI",
    Desc = "Opponent: None (Awaiting Combat)\nCounter Rule: Grass ➔ Fire 🔥 | Rock ➔ Water 💧 | Water ➔ Grass 🌿\nMove Selector: Maximum Super-Effective Damage (2.0x)"
})

TabIslandFarm:Toggle({
    Title = "Enable Smart Elemental Battle AI",
    Desc = "Master toggle: Detects opponent element, equips counter Evomon, and selects the most damaging moves",
    Value = HubState.SmartCombatAI,
    Callback = function(state)
        HubState.SmartCombatAI = state
    end
})

TabIslandFarm:Toggle({
    Title = "Auto Counter Evomon Selection",
    Desc = "Automatically aligns your starter/main Evomon to counter the opponent's element (Fire vs Grass, Water vs Rock/Fire, Grass vs Water/Rock)",
    Value = HubState.AutoSwitchPetCounter,
    Callback = function(state)
        HubState.AutoSwitchPetCounter = state
    end
})

TabIslandFarm:Toggle({
    Title = "Smart Move Optimizer (Highest Damage / 2.0x)",
    Desc = "Calculates exact damage multipliers against opponent and casts Super-Effective (2.0x) moves",
    Value = HubState.AutoPickBestMove,
    Callback = function(state)
        HubState.AutoPickBestMove = state
    end
})

TabIslandFarm:Toggle({
    Title = "Auto Cast Ultimate Move",
    Desc = "Fires your Evomon's Ultimate attack as soon as it is charged and available",
    Value = HubState.AutoCastUltimate,
    Callback = function(state)
        HubState.AutoCastUltimate = state
    end
})

TabIslandFarm:Section({ Title = "Combat & Leveling Controls" })

TabIslandFarm:Toggle({
    Title = "Auto Battle (V Mode)",
    Desc = "Auto-activates in-game 'V' mode once when entering battle. Turning this OFF stays OFF without reverting!",
    Value = HubState.AutoBattle,
    Callback = function(state)
        HubState.AutoBattle = state
        SetAutoBattleState(state)
        if not state then
            WindUI:Notify({
                Title = "Auto Battle Disabled",
                Content = "Auto battle (V) mode is turned off and won't auto-enable.",
                Duration = 2.5,
                Icon = "shield-off"
            })
        else
            WindUI:Notify({
                Title = "Auto Battle Enabled",
                Content = "Will engage auto battle (V) upon entering combat.",
                Duration = 2.5,
                Icon = "swords"
            })
        end
    end
})

TabIslandFarm:Toggle({
    Title = "Auto Level Breakthrough",
    Desc = "Automatically breaks through Evomon & player level caps when max level is reached",
    Value = true,
    Callback = function(state)
        HubState.AutoLevelBreakthrough = state
        if state then
            TriggerLevelBreakthrough()
        end
    end
})

TabIslandFarm:Toggle({
    Title = "Auto Claim Level Rewards",
    Desc = "Automatically claims rewards whenever your player or Evomons level up",
    Value = true,
    Callback = function(state)
        HubState.AutoClaimLevelRewards = state
        if state then
            TriggerClaimLevelRewards()
        end
    end
})

TabIslandFarm:Toggle({
    Title = "Auto Dismiss Popups / Level Windows",
    Desc = "Closes reward and skill popups after battle so farming never freezes or gets stuck",
    Value = true,
    Callback = function(state)
        HubState.AutoDismissPopups = state
    end
})

TabIslandFarm:Button({
    Title = "Breakthrough Level Cap Now",
    Desc = "Manually triggers level breakthrough for Evomons & player",
    Callback = function()
        TriggerLevelBreakthrough()
        WindUI:Notify({ Title = "Level Breakthrough", Content = "Triggered level breakthrough request.", Duration = 2.5, Icon = "zap" })
    end
})

TabIslandFarm:Button({
    Title = "Claim Level Rewards Now",
    Desc = "Manually claims any pending player level rewards",
    Callback = function()
        TriggerClaimLevelRewards()
        WindUI:Notify({ Title = "Level Rewards", Content = "Triggered level reward claim request.", Duration = 2.5, Icon = "gift" })
    end
})

TabIslandFarm:Button({
    Title = "Dismiss All Popups Now",
    Desc = "Force-closes any open reward, skill replacement, or level-up windows",
    Callback = function()
        DismissBlockingWindows()
        WindUI:Notify({ Title = "Dismiss Popups", Content = "Closed blocking popups.", Duration = 2, Icon = "x" })
    end
})

TabIslandFarm:Section({ Title = "World Boss Instant Actions" })

TabIslandFarm:Toggle({
    Title = "Auto Kill Boss When Reached",
    Desc = "Automatically warps to and challenges World Boss when progression reaches the Boss Island",
    Value = true,
    Callback = function(state)
        HubState.AutoKillBoss = state
    end
})

TabIslandFarm:Button({
    Title = "Teleport Directly To World Boss",
    Desc = "Warps immediately to World Boss Island (World1BossIsland1)",
    Callback = function()
        TeleportTo(Vector3.new(12654, 598, -9070))
        WindUI:Notify({
            Title = "Boss Island",
            Content = "Teleported to World Boss Island!",
            Duration = 3,
            Icon = "skull"
        })
    end
})

TabIslandFarm:Button({
    Title = "Next Island Now (Skip)",
    Desc = "Forces the bot to advance to the next island immediately",
    Callback = function()
        HubState.CurrentIslandIndex = (HubState.CurrentIslandIndex % #IslandData) + 1
        HubState.FarmsOnCurrentIsland = 0
        local nextIsland = IslandData[HubState.CurrentIslandIndex]
        if nextIsland then
            TeleportTo(nextIsland.pos)
            WindUI:Notify({
                Title = "Advancing to Next Island",
                Content = "Arrived at " .. nextIsland.name,
                Duration = 3,
                Icon = "arrow-right"
            })
        end
    end
})

-- ===================================================
-- TAB 3: WILD EVOMONS & ESP (WITH CLEAN TOGGLE OFF)
-- ===================================================

TabRadar:Section({ Title = "Wild Evomon Radar & ESP" })

local RadarInfoPara = TabRadar:Paragraph({
    Title = "Radar Overview",
    Desc = "Scanning wild Evomons in the world..."
})

-- Toggle with guaranteed instant destruction on OFF
TabRadar:Toggle({
    Title = "Wild Evomon ESP",
    Desc = "Shows name, level, and distance tags above wild Evomons (Instant clean on toggle OFF)",
    Value = false,
    Callback = function(state)
        HubState.EvomonESP = state
        if not state then
            ClearAllESP()
            WindUI:Notify({
                Title = "ESP Disabled",
                Content = "All ESP tags and anchor parts removed cleanly.",
                Duration = 2,
                Icon = "eye-off"
            })
        else
            WindUI:Notify({
                Title = "ESP Enabled",
                Content = "Tracking nearby wild Evomons.",
                Duration = 2,
                Icon = "eye"
            })
        end
    end
})

TabRadar:Button({
    Title = "Clear All Leftover ESP Now",
    Desc = "Forces a complete wipe of all billboard tags and anchor objects",
    Callback = function()
        ClearAllESP()
        WindUI:Notify({
            Title = "ESP Cleared",
            Content = "All tags wiped successfully.",
            Duration = 2,
            Icon = "trash-2"
        })
    end
})

TabRadar:Section({ Title = "Target & Active Battles" })

TabRadar:Button({
    Title = "Fight Closest Evomon Now",
    Desc = "Teleports to the closest Evomon and immediately initiates battle",
    Callback = function()
        local list = FetchWildCreatures()
        if #list > 0 then
            local target = list[1]
            TeleportTo(target.cframe)
            task.delay(0.2, function()
                if BattleService and BattleService.enterPetBattle then
                    pcall(function()
                        BattleService.enterPetBattle(tostring(target.uid))
                    end)
                end
            end)
            WindUI:Notify({
                Title = "Fighting " .. target.name,
                Content = string.format("Level %d - Starting Battle!", target.level),
                Duration = 3,
                Icon = "swords"
            })
        end
    end
})

TabRadar:Button({
    Title = "Teleport To Closest Evomon",
    Callback = function()
        local list = FetchWildCreatures()
        if #list > 0 then
            local target = list[1]
            TeleportTo(target.cframe)
            WindUI:Notify({
                Title = "Teleported to " .. target.name,
                Content = string.format("Level %d (Distance: %d studs)", target.level, math.floor(target.distance)),
                Duration = 3,
                Icon = "map-pin"
            })
        end
    end
})

TabRadar:Button({
    Title = "Teleport To Highest Level Evomon",
    Callback = function()
        local list = FetchWildCreatures()
        if #list > 0 then
            local highest = list[1]
            for _, c in ipairs(list) do
                if c.level > highest.level then
                    highest = c
                end
            end
            TeleportTo(highest.cframe)
            WindUI:Notify({
                Title = "High-Level Evomon Found!",
                Content = string.format("%s (Lvl %d) located at %d studs", highest.name, highest.level, math.floor(highest.distance)),
                Duration = 3.5,
                Icon = "zap"
            })
        end
    end
})

-- ===================================================
-- TAB 4: AUTO REWARDS & CODES
-- ===================================================

TabRewards:Section({ Title = "One-Click Promo Code Redemption" })

TabRewards:Button({
    Title = "Redeem ALL Active Codes (21 Verified Codes)",
    Desc = "Batch redeems all 21 current promo codes (Tickets, Potions, Coins & EXP fruits)",
    Callback = function()
        WindUI:Notify({ Title = "Redeeming Codes...", Content = "Processing all promo codes...", Duration = 2, Icon = "loader" })
        local count = RedeemAllCodes()
        WindUI:Notify({
            Title = "Code Batch Finished!",
            Content = string.format("Claimed %d new codes successfully!", count),
            Duration = 4,
            Icon = "check"
        })
    end
})

local CustomCodeInput = ""
TabRewards:Input({
    Title = "Custom Code",
    Placeholder = "Enter any new promo code",
    Callback = function(val)
        CustomCodeInput = val
    end
})

TabRewards:Button({
    Title = "Redeem Single Code",
    Callback = function()
        if CustomCodeInput == "" then
            WindUI:Notify({ Title = "Error", Content = "Please enter a code first.", Duration = 2, Icon = "x" })
            return
        end
        local res = RedeemCode(CustomCodeInput)
        if res == 20000 then
            WindUI:Notify({ Title = "Success!", Content = "Code successfully redeemed!", Duration = 3, Icon = "check" })
        else
            WindUI:Notify({ Title = "Code Response", Content = "Code expired or already claimed (" .. tostring(res) .. ")", Duration = 2.5, Icon = "info" })
        end
    end
})

TabRewards:Section({ Title = "One-Click Free Rewards" })

TabRewards:Button({
    Title = "Claim All Mail Rewards",
    Callback = function()
        local ok = ClaimMail()
        WindUI:Notify({
            Title = "Mail Rewards",
            Content = ok and "All mailbox rewards claimed!" or "Mail rewards already claimed or empty.",
            Duration = 2.5,
            Icon = "mail"
        })
    end
})

TabRewards:Button({
    Title = "Claim Daily Reward",
    Callback = function()
        local ok = ClaimDaily()
        WindUI:Notify({
            Title = "Daily Reward",
            Content = ok and "Daily reward claimed!" or "Daily reward already claimed today.",
            Duration = 2.5,
            Icon = "calendar"
        })
    end
})

TabRewards:Button({
    Title = "Claim Group Reward",
    Callback = function()
        local ok = ClaimGroup()
        WindUI:Notify({
            Title = "Group Reward",
            Content = ok and "Group reward claimed!" or "Make sure you joined the Roblox group first.",
            Duration = 3,
            Icon = "users"
        })
    end
})

-- ===================================================
-- TAB 5: WORLD TELEPORTS
-- ===================================================

TabTeleports:Section({ Title = "Island Waypoints (Safe Walk / Travel)" })

for _, isl in ipairs(IslandData) do
    TabTeleports:Button({
        Title = "Walk to " .. isl.name,
        Callback = function()
            WindUI:Notify({ Title = "Walking to " .. isl.name, Content = "Navigating safely using legit movement...", Duration = 3, Icon = "footprints" })
            task.spawn(function()
                SafeMoveTo(isl.pos, 10, 60)
                WindUI:Notify({ Title = "Arrived", Content = "Safely arrived at " .. isl.name, Duration = 2.5, Icon = "check" })
            end)
        end
    })
end

TabTeleports:Section({ Title = "Special Hubs" })

TabTeleports:Button({
    Title = "Enter Trading Hall",
    Callback = function()
        pcall(function()
            local mw = Remote:FindFirstChild("ManyWorlds") and Remote.ManyWorlds:FindFirstChild("ReqApplyEnterTradingHall")
            if mw then
                mw:InvokeServer()
                WindUI:Notify({ Title = "Trading Hall", Content = "Requested Trading Hall entry.", Duration = 2.5, Icon = "shopping-bag" })
            end
        end)
    end
})

-- ===================================================
-- TAB 6: PLAYER & UTILITIES
-- ===================================================

TabPlayer:Section({ Title = "Safe Movement & Anti-Detection" })

TabPlayer:Dropdown({
    Title = "Movement Mode",
    Desc = "Legit Walk is 100% safe (uses character controller). Chunk-Hop Blink breaks travel into small safe hops.",
    Values = { "Legit Walk (Safest - No TP)", "Chunk-Hop Blink (Fast & Safe)", "Smooth Glide (Tween)" },
    Value = "Legit Walk (Safest - No TP)",
    Callback = function(val)
        if string.find(val, "Walk") then
            HubState.MovementMode = "Walk"
        elseif string.find(val, "Blink") or string.find(val, "Chunk") then
            HubState.MovementMode = "Blink"
        elseif string.find(val, "Glide") or string.find(val, "Tween") then
            HubState.MovementMode = "Tween"
        else
            HubState.MovementMode = "Walk"
        end
    end
})

TabPlayer:Slider({
    Title = "Post-Move Settle Delay",
    Desc = "Delay in seconds before interacting/fighting after arriving to let server position sync",
    Value = { Min = 0.2, Max = 1.5, Default = 0.4 },
    Step = 0.05,
    Callback = function(val)
        HubState.PostTpDelay = val
    end
})

TabPlayer:Slider({
    Title = "Auto-Move WalkSpeed",
    Desc = "Speed applied to your character when walking/running to targets",
    Value = { Min = 16, Max = 45, Default = 16 },
    Step = 1,
    Callback = function(val)
        HubState.WalkSpeedBoost = val
    end
})

TabPlayer:Slider({
    Title = "Combat Arrival Distance",
    Desc = "Distance to creature before triggering battle",
    Value = { Min = 4, Max = 16, Default = 8 },
    Step = 1,
    Callback = function(val)
        HubState.ArrivalDistance = val
    end
})

TabPlayer:Section({ Title = "Character Modifiers (Safe Limits)" })

TabPlayer:Toggle({
    Title = "Enable Safe WalkSpeed Boost",
    Desc = "Caps speed within legitimate network limits (16 - 28)",
    Value = false,
    Callback = function(state)
        HubState.SpeedEnabled = state
        if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
        end
    end
})

TabPlayer:Slider({
    Title = "WalkSpeed (Safe Cap: 28)",
    Value = { Min = 16, Max = 28, Default = 16 },
    Step = 1,
    Callback = function(val)
        HubState.CustomSpeed = math.clamp(val, 16, 28)
        if HubState.SpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = HubState.CustomSpeed
        end
    end
})

TabPlayer:Toggle({
    Title = "Anti-AFK Protection",
    Desc = "Sends native engine key event to prevent idle disconnect without detection",
    Value = true,
    Callback = function(state)
        HubState.AntiAFK = state
    end
})

TabPlayer:Section({ Title = "Hub Management" })

TabPlayer:Button({
    Title = "Unload Hub",
    Callback = function()
        Cleanup()
    end
})

-- ====================
-- BACKGROUND LOOPS & EVENT CONNECTIONS
-- ====================

-- Anti-AFK Listener
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

table.insert(HubState.Connections, LocalPlayer.Idled:Connect(function()
    if HubState.AntiAFK then
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
            else
                -- Fallback: simulate minor micro-movement via humanoid (100% undetectable)
                local hum = GetHumanoid()
                if hum then
                    hum:Move(Vector3.new(0.01, 0, 0.01))
                    task.wait(0.1)
                    hum:Move(Vector3.zero)
                end
            end
        end)
    end
end))

-- Infinite Jump removed for account safety

-- Character Respawn Handler
table.insert(HubState.Connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    local hum = newChar:WaitForChild("Humanoid", 10)
    if hum then
        if HubState.SpeedEnabled then hum.WalkSpeed = HubState.CustomSpeed end
        if HubState.JumpEnabled then hum.UseJumpPower = true; hum.JumpPower = HubState.CustomJump end
    end
end))

-- Main Heartbeat Loop
table.insert(HubState.Connections, RunService.Heartbeat:Connect(function()
    if not HubState.Running then return end

    -- Speed & Jump enforcement
    if Character and Character:FindFirstChild("Humanoid") then
        local hum = Character.Humanoid
        if HubState.SpeedEnabled and hum.WalkSpeed ~= HubState.CustomSpeed then
            hum.WalkSpeed = HubState.CustomSpeed
        end
        if HubState.JumpEnabled and hum.JumpPower ~= HubState.CustomJump then
            hum.UseJumpPower = true
            hum.JumpPower = HubState.CustomJump
        end
    end

-- NoClip removed for account safety

    -- Battle Status & Tracking
    local inBattle, battleWin = IsInBattle()
    local sessionActive = (BattleService and BattleService.hasActiveBattleSession and BattleService.hasActiveBattleSession()) or false
    local currentCombat = inBattle or sessionActive

    -- Track battle start -> Handle Auto Battle vs Smart Combat
    if HubState.LastBattleState == false and currentCombat == true then
        -- Enable native Auto-Battle on combat start to ensure server rounds execute seamlessly
        SetAutoBattleState(true)
        if HubState.AutoQuest then
            pcall(function()
                local bc = require(ReplicatedStorage.Controller.BattleCatchPetWindowController)
                if bc and bc.triggerAutoCatchButton then bc.triggerAutoCatchButton() end
            end)
        end
        -- Trigger first combat move immediately on battle start
        if HubState.SmartCombatAI then
            task.spawn(ExecuteSmartCombatStep)
        end
    end

    -- In-combat Smart Elemental Move Optimizer (Rapid 0.25s check so turns are never missed)
    if currentCombat and HubState.SmartCombatAI then
        local nowCombatTime = os.clock()
        if (nowCombatTime - HubState.LastTurnMoveTime) >= 0.25 then
            HubState.LastTurnMoveTime = nowCombatTime
            task.spawn(ExecuteSmartCombatStep)
        end
    end

    -- Track battle end -> Progression count, level cap breakthrough & claim rewards
    if HubState.LastBattleState == true and currentCombat == false then
        HubState.FarmsOnCurrentIsland = HubState.FarmsOnCurrentIsland + 1

        -- Ensure any residual session is marked complete
        pcall(function()
            if BattleService and BattleService.completeBattleSession then
                BattleService.completeBattleSession()
            end
        end)

        -- Post-battle level up & reward handling
        task.spawn(function()
            task.wait(0.4)
            if HubState.AutoDismissPopups then
                DismissBlockingWindows()
            end
            if HubState.AutoLevelBreakthrough then
                TriggerLevelBreakthrough()
            end
            if HubState.AutoClaimLevelRewards then
                TriggerClaimLevelRewards()
            end
            -- Auto-claim quest if it was completed during battle & immediately run next step
            if HubState.AutoQuest or HubState.AutoQuestClaim then
                local q = GetCurrentQuestInfo()
                if q and (q.isClaimable or q.isCompleted) then
                    pcall(function()
                        Remote.Task.ReqCompleteTask:InvokeServer(q.taskId)
                    end)
                    DismissBlockingWindows()
                end
                if HubState.AutoQuest then
                    task.delay(0.5, ExecuteQuestStep)
                end
            end
        end)

        -- Check if Island farm quota reached
        if HubState.IslandAutoFarm and HubState.FarmsOnCurrentIsland >= HubState.FarmsPerIsland then
            HubState.FarmsOnCurrentIsland = 0
            HubState.CurrentIslandIndex = (HubState.CurrentIslandIndex % #IslandData) + 1
            local nextIsl = IslandData[HubState.CurrentIslandIndex]
            if nextIsl then
                task.wait(1.2)
                TeleportTo(nextIsl.pos)
                WindUI:Notify({
                    Title = "Island Complete!",
                    Content = "Advancing to " .. nextIsl.name,
                    Duration = 3,
                    Icon = "check"
                })
            end
        end
    end
    HubState.LastBattleState = currentCombat

    -- Escape Helper (Only if configured)
    if inBattle and battleWin and HubState.AutoEscapeIfHighLevel and battleWin.EnemyPetLevelText and battleWin.EscapeButton then
        local lvlNum = tonumber(battleWin.EnemyPetLevelText.Text:match("%d+"))
        if lvlNum and lvlNum >= HubState.EscapeLevelThreshold then
            pcall(function()
                for _, c in ipairs(getconnections(battleWin.EscapeButton.Activated)) do
                    c:Fire()
                end
            end)
        end
    end

    local now = os.clock()

    -- Auto Quest Solver Loop (Legit Walking Mode)
    if HubState.AutoQuest and not currentCombat and not HubState.IsNavigating and (now - HubState.LastQuestStep >= math.min(HubState.QuestStepDelay or 2.5, 2.0)) then
        HubState.LastQuestStep = now
        task.spawn(ExecuteQuestStep)
    end

    -- Island Progression Auto Farm Loop (Only if AutoQuest is not busy and not currently walking)
    if HubState.IslandAutoFarm and not HubState.AutoQuest and not currentCombat and not HubState.IsNavigating and (now - HubState.LastFarmTeleport >= HubState.FarmDelay) then
        if HubState.AutoDismissPopups then
            DismissBlockingWindows()
        end

        HubState.LastFarmTeleport = now
        local curIsland = IslandData[HubState.CurrentIslandIndex]
        if curIsland then
            -- World Boss Island
            if curIsland.id == 99 then
                task.spawn(function()
                    SafeMoveTo(curIsland.pos, 10, 15)
                    pcall(function()
                        if BattleService and BattleService.reportEnterBossBattle then
                            BattleService.reportEnterBossBattle(1)
                        end
                    end)
                end)
            else
                -- Wild Evomon on current island
                local islandEvomons = GetCreaturesNearPos(curIsland.pos, HubState.FarmRadius)
                if #islandEvomons > 0 then
                    local target = islandEvomons[1]
                    -- Smart Elemental Counter Selection before island combat
                    if HubState.SmartCombatAI and HubState.AutoSwitchPetCounter and target.cfgId then
                        local petCfg = PetConfig and PetConfig[target.cfgId]
                        if petCfg and petCfg.mainElement then
                            AlignPetCounter(petCfg.mainElement)
                        end
                    end
                    -- Walk naturally to creature before triggering battle
                    task.spawn(function()
                        SafeMoveTo(target.cframe, HubState.ArrivalDistance or 8, 12)
                        task.wait(0.35) -- Natural pause so server confirms standing in front of creature
                        if not IsInBattle() and BattleService and BattleService.enterPetBattle then
                            pcall(function()
                                BattleService.enterPetBattle(tostring(target.uid))
                            end)
                        end
                    end)
                else
                    task.spawn(function()
                        SafeMoveTo(curIsland.pos, 15, 15)
                    end)
                end
            end
        end
    end
end))

-- Periodic Radar, ESP & Background Leveling Updater (every 1.5 seconds)
task.spawn(function()
    while HubState.Running do
        pcall(function()
            -- ESP Complete Wipe when turned off
            if not HubState.EvomonESP then
                if ESPContainerFolder and #ESPContainerFolder:GetChildren() > 0 then
                    ESPContainerFolder:ClearAllChildren()
                end
                if ESPGui and #ESPGui:GetChildren() > 0 then
                    ESPGui:ClearAllChildren()
                end
                if next(HubState.ESPObjects) ~= nil then
                    table.clear(HubState.ESPObjects)
                end
            else
                -- ESP is ON
                local creatures = FetchWildCreatures()
                local root = GetRootPart()
                local rootPos = root and root.Position or Vector3.zero
                local activeUids = {}

                for _, c in ipairs(creatures) do
                    if c.distance <= 350 then
                        activeUids[c.uid] = true
                        local esp = HubState.ESPObjects[c.uid]
                        if not esp or not esp.gui.Parent or not esp.part.Parent then
                            local bg = Instance.new("BillboardGui")
                            bg.Name = "EvomonESP_" .. c.uid
                            bg.AlwaysOnTop = true
                            bg.Size = UDim2.new(0, 140, 0, 36)
                            bg.StudsOffset = Vector3.new(0, 3, 0)

                            local frame = Instance.new("Frame", bg)
                            frame.Size = UDim2.new(1, 0, 1, 0)
                            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
                            frame.BackgroundTransparency = 0.25
                            local corner = Instance.new("UICorner", frame)
                            corner.CornerRadius = UDim.new(0, 6)

                            local stroke = Instance.new("UIStroke", frame)
                            stroke.Color = Color3.fromRGB(168, 85, 247)
                            stroke.Thickness = 1.5

                            local label = Instance.new("TextLabel", frame)
                            label.Name = "Info"
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextColor3 = Color3.fromRGB(255, 255, 255)
                            label.Font = Enum.Font.GothamBold
                            label.TextSize = 11
                            label.Text = string.format("%s [Lv.%d]\n%dm", c.name, c.level, math.floor(c.distance))

                            -- Anchor part placed inside dedicated container
                            local part = Instance.new("Part")
                            part.Name = "Anchor_" .. c.uid
                            part.Size = Vector3.new(0.5, 0.5, 0.5)
                            part.Transparency = 1
                            part.Anchored = true
                            part.CanCollide = false
                            part.CFrame = c.cframe
                            part.Parent = ESPContainerFolder

                            bg.Adornee = part
                            bg.Parent = ESPGui

                            HubState.ESPObjects[c.uid] = {gui = bg, part = part, label = label}
                        else
                            esp.label.Text = string.format("%s [Lv.%d]\n%dm", c.name, c.level, math.floor(c.distance))
                            esp.part.CFrame = c.cframe
                        end
                    end
                end

                -- Remove out of range
                for uid, item in pairs(HubState.ESPObjects) do
                    if not activeUids[uid] then
                        pcall(function() item.gui:Destroy(); item.part:Destroy() end)
                        HubState.ESPObjects[uid] = nil
                    end
                end
            end

            -- Background Level Breakthrough & Reward checks
            local now = os.clock()
            if (now - HubState.LastPeriodicCheck) >= 4.0 then
                HubState.LastPeriodicCheck = now
                if HubState.AutoLevelBreakthrough then
                    TriggerLevelBreakthrough()
                end
                if HubState.AutoClaimLevelRewards then
                    TriggerClaimLevelRewards()
                end
                if HubState.AutoDismissPopups and not IsInBattle() then
                    DismissBlockingWindows()
                end
            end

            -- Update Live Quest Status
            local qInfo = GetCurrentQuestInfo()
            if qInfo and (qInfo.taskId or qInfo.name ~= "No Active Quest") then
                local statusStr = HubState.AutoQuest and "Active (Completing Quest)" or "Idle"
                local claimStr = (qInfo.isClaimable or qInfo.isCompleted) and "READY TO CLAIM!" or "In Progress"
                local targetIsl = qInfo.targetIsland and qInfo.targetIsland.name or "Current Island"
                local bossStr = qInfo.isBossTask and ("Boss Target: " .. (qInfo.bossName or "King")) or "Standard Objective"
                QuestStatusPara:SetDesc(string.format(
                    "Status: %s\nQuest: %s\nProgress: %s\nTarget Island: %s\nType: %s\nState: %s\nTask ID: %s",
                    statusStr,
                    qInfo.name,
                    qInfo.progress ~= "" and qInfo.progress or "Tracking (0/1)",
                    targetIsl,
                    bossStr,
                    claimStr,
                    tostring(qInfo.taskId or "Active")
                ))
            end

            -- Update UI Dashboards
            local creatures = FetchWildCreatures()
            local closest = HubState.ClosestEvomon
            local curIsland = IslandData[HubState.CurrentIslandIndex]

            if closest then
                RadarInfoPara:SetDesc(string.format(
                    "🐾 Wild Evomons in World: %d\n🎯 Closest: %s (Lvl %d)\n📏 Distance: %d studs",
                    #creatures, closest.name, closest.level, math.floor(closest.distance)
                ))
            end

            local farmStatus = HubState.IslandAutoFarm and "🟢 Active (Farming & Fighting)" or "⚪ Idle"
            FarmStatusPara:SetDesc(string.format(
                "Status: %s\n🏝️ Island: %s\n🎯 Progress: %d / %d Evomons\n👑 Next Boss: World Boss Island",
                farmStatus,
                curIsland and curIsland.name or "Island 1",
                HubState.FarmsOnCurrentIsland,
                HubState.FarmsPerIsland
            ))
        end)
        task.wait(1.5)
    end
end)

-- Global exposure for macros & console
_G.EvomonHub = {
    State = HubState,
    RedeemAllCodes = RedeemAllCodes,
    ClaimMail = ClaimMail,
    ClaimDaily = ClaimDaily,
    ClearAllESP = ClearAllESP,
    GetCurrentQuestInfo = GetCurrentQuestInfo,
    ExecuteQuestStep = ExecuteQuestStep,
    TriggerLevelBreakthrough = TriggerLevelBreakthrough,
    TriggerClaimLevelRewards = TriggerClaimLevelRewards,
    DismissBlockingWindows = DismissBlockingWindows,
    TeleportToClosest = function()
        local list = FetchWildCreatures()
        if list[1] then TeleportTo(list[1].cframe) end
    end,
    FightClosest = function()
        local list = FetchWildCreatures()
        if list[1] then
            task.spawn(function()
                SafeMoveTo(list[1].cframe, HubState.ArrivalDistance or 8, 15)
                task.wait(0.1)
                if BattleService and BattleService.enterPetBattle then
                    BattleService.enterPetBattle(tostring(list[1].uid))
                end
            end)
        end
    end,
    SafeMoveTo = SafeMoveTo,
    TeleportTo = TeleportTo
}

WindUI:Notify({
    Title = "Evomon Hub Ready!",
    Content = "Full Auto Quest & Story Completer is operational!",
    Duration = 4,
    Icon = "scroll"
})

return Window
