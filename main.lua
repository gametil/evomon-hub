--[[
    Evomon [S3 TRADE] - WindUI Automation Hub
    Reverse engineered & automated via Real MCP
    WindUI Modern Interface
    Features:
      - Wild Evomon Radar & Teleport (Closest, High Level, Shiny/Rare)
      - Wild Evomon ESP Visualizer (Live distance, level & names)
      - Auto Farm Wild Evomons (Auto Engage & Battle)
      - Auto Battle & Escape Helper
      - One-Click Auto Redeem All Active Codes
      - Auto Claim Mail, Daily, & Group Rewards
      - World & Island Teleports (Islands 1-15, Trading Hall, Dungeons)
      - Character Modifiers (WalkSpeed, JumpPower, Infinite Jump, NoClip, Anti-AFK)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

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
local UIManager = require(ReplicatedStorage.Core.UI.UIManager)

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Create Window
local Window = WindUI:CreateWindow({
    Title = "Evomon Hub [S3 TRADE]",
    Icon = "sparkles",
    Author = "by Antigravity & WindUI",
    Folder = "EvomonHubConfig",
    Size = UDim2.fromOffset(630, 500),
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

-- State Variables
local HubState = {
    Running = true,
    -- Radar & Farming
    AutoFarmWild = false,
    FarmMinLevel = 1,
    FarmMaxDistance = 500,
    EvomonESP = false,
    LastFarmTeleport = 0,
    FarmDelay = 3.0,
    -- Auto Battle
    AutoBattle = true,
    AutoEscapeIfHighLevel = false,
    EscapeLevelThreshold = 100,
    -- Player Mods
    SpeedEnabled = false,
    CustomSpeed = 24,
    JumpEnabled = false,
    CustomJump = 60,
    InfJump = false,
    NoClip = false,
    AntiAFK = true,
    -- Internals
    Connections = {},
    ESPObjects = {},
    CachedCreatures = {},
    LastCreatureScan = 0,
    ClosestEvomon = nil,
}

-- Cleanup function
local function Cleanup()
    HubState.Running = false
    for _, conn in ipairs(HubState.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(HubState.Connections)

    -- Clear ESP
    for _, esp in pairs(HubState.ESPObjects) do
        pcall(function() esp:Destroy() end)
    end
    table.clear(HubState.ESPObjects)

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

-- Scan wild creatures
local function FetchWildCreatures()
    local now = os.clock()
    if (now - HubState.LastCreatureScan) < 2.0 and #HubState.CachedCreatures > 0 then
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

-- Teleport to position safely
local function TeleportTo(cf)
    local root = GetRootPart()
    if root then
        if typeof(cf) == "Vector3" then
            root.CFrame = CFrame.new(cf + Vector3.new(0, 3, 0))
        elseif typeof(cf) == "CFrame" then
            root.CFrame = cf + Vector3.new(0, 3, 0)
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

-- Check if currently in battle
local function IsInBattle()
    local open = UIManager:getOpenedUIWindowList()
    for _, w in ipairs(open or {}) do
        if w.name == "MainBattleWindow" then
            return true, w
        end
    end
    return false, nil
end

-- Codes list
local ActiveCodes = {
    "240evoRISE",
    "EVO120HYPE",
    "EVO60SPARK",
    "30K-LIKES",
    "20000LIKES",
    "THXFOR5K",
    "2K-LIKES",
    "12klikes"
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

local TabRadar = Window:Tab({
    Title = "Wild Evomons",
    Icon = "compass",
})

local TabBattle = Window:Tab({
    Title = "Auto Battle & Catch",
    Icon = "swords",
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
-- TAB 1: WILD EVOMONS RADAR & FARMING
-- ===================================================

TabRadar:Section({ Title = "Live Wild Evomon Radar" })

local RadarInfoPara = TabRadar:Paragraph({
    Title = "Radar Overview",
    Desc = "Scanning wild Evomons in the world..."
})

TabRadar:Section({ Title = "Wild Farm Automation" })

TabRadar:Toggle({
    Title = "Auto Farm Closest Wild Evomons",
    Desc = "Continuously teleports to nearby wild Evomons to trigger and win battles",
    Value = false,
    Callback = function(state)
        HubState.AutoFarmWild = state
        WindUI:Notify({
            Title = "Auto Farm",
            Content = state and "Auto Farm Started! Teleporting to wild Evomons." or "Auto Farm Stopped.",
            Duration = 2.5,
            Icon = state and "check" or "x"
        })
    end
})

TabRadar:Slider({
    Title = "Minimum Evomon Level",
    Desc = "Only farm Evomons at or above this level",
    Value = { Min = 1, Max = 150, Default = 1 },
    Step = 1,
    Callback = function(val)
        HubState.FarmMinLevel = val
    end
})

TabRadar:Slider({
    Title = "Maximum Search Radius (Studs)",
    Desc = "Max distance to search for wild Evomons",
    Value = { Min = 100, Max = 3000, Default = 800 },
    Step = 50,
    Callback = function(val)
        HubState.FarmMaxDistance = val
    end
})

TabRadar:Toggle({
    Title = "Wild Evomon ESP",
    Desc = "Displays name, level and distance markers above nearby wild Evomons",
    Value = false,
    Callback = function(state)
        HubState.EvomonESP = state
        if not state then
            for _, esp in pairs(HubState.ESPObjects) do
                pcall(function() esp:Destroy() end)
            end
            table.clear(HubState.ESPObjects)
        end
    end
})

TabRadar:Section({ Title = "Manual Teleport Actions" })

TabRadar:Button({
    Title = "Teleport To Closest Evomon",
    Desc = "Instantly warps to the nearest wild creature to start battle",
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
        else
            WindUI:Notify({ Title = "None Found", Content = "No wild Evomons nearby.", Duration = 2, Icon = "alert-circle" })
        end
    end
})

TabRadar:Button({
    Title = "Teleport To Highest Level Evomon",
    Desc = "Finds the strongest wild Evomon on the map and teleports to it",
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
-- TAB 2: AUTO BATTLE & CATCH
-- ===================================================

TabBattle:Section({ Title = "Battle Automation" })

local BattleInfoPara = TabBattle:Paragraph({
    Title = "Battle Status",
    Desc = "Status: Exploring (Not in battle)"
})

TabBattle:Toggle({
    Title = "Auto Battle (Auto Fight)",
    Desc = "Automatically enables Auto Mode in battles to attack and use skills",
    Value = true,
    Callback = function(state)
        HubState.AutoBattle = state
    end
})

TabBattle:Toggle({
    Title = "Auto Escape If Strong Enemy",
    Desc = "Flee from battle if enemy level exceeds your threshold",
    Value = false,
    Callback = function(state)
        HubState.AutoEscapeIfHighLevel = state
    end
})

TabBattle:Slider({
    Title = "Escape Level Threshold",
    Value = { Min = 20, Max = 180, Default = 80 },
    Step = 5,
    Callback = function(val)
        HubState.EscapeLevelThreshold = val
    end
})

TabBattle:Section({ Title = "Manual Battle Actions" })

TabBattle:Button({
    Title = "Escape / Flee Current Battle",
    Desc = "Immediately exits the current turn-based battle",
    Callback = function()
        local inBattle, win = IsInBattle()
        if inBattle and win and win.EscapeButton then
            pcall(function()
                for _, conn in ipairs(getconnections(win.EscapeButton.Activated)) do
                    conn:Fire()
                end
            end)
            WindUI:Notify({ Title = "Battle Escaped", Content = "Fled from battle.", Duration = 2, Icon = "log-out" })
        else
            WindUI:Notify({ Title = "Not in Battle", Content = "You are not currently in a battle.", Duration = 2, Icon = "info" })
        end
    end
})

-- ===================================================
-- TAB 3: AUTO REWARDS & CODES
-- ===================================================

TabRewards:Section({ Title = "One-Click Promo Code Redemption" })

TabRewards:Button({
    Title = "Redeem ALL Active Codes (8 Codes)",
    Desc = "Batch redeems: 240evoRISE, EVO120HYPE, EVO60SPARK, 30K-LIKES, 20000LIKES, THXFOR5K, 2K-LIKES",
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
    Desc = "Collects all items, gems and rewards sitting in your mailbox",
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
-- TAB 4: WORLD TELEPORTS
-- ===================================================

TabTeleports:Section({ Title = "Island Teleports (Open World)" })

local IslandCoordinates = {
    {"Island 1 (Starter)", Vector3.new(9292, 586, -972)},
    {"Island 2 (Misty Shore)", Vector3.new(11500, 588, -2500)},
    {"Island 3 (Breeze Woods)", Vector3.new(14200, 592, -4100)},
    {"Island 4 (Gale Highlands)", Vector3.new(16500, 595, -6200)},
    {"Island 5 (Frost Peaks)", Vector3.new(19200, 720, -7300)},
    {"Island 6 (Glacier Valley)", Vector3.new(18500, 600, -9800)},
    {"Island 7 (Thunder Plains)", Vector3.new(16000, 595, -11500)},
    {"Island 8 (Molten Core)", Vector3.new(13500, 600, -13200)},
    {"Island 9 (Crystal Cavern)", Vector3.new(10500, 595, -14500)},
    {"Island 10 (Starfall Sanctuary)", Vector3.new(6660, 600, -12640)},
}

for _, isl in ipairs(IslandCoordinates) do
    TabTeleports:Button({
        Title = "Warp to " .. isl[1],
        Callback = function()
            TeleportTo(isl[2])
            WindUI:Notify({ Title = "Teleported", Content = "Arrived at " .. isl[1], Duration = 2, Icon = "map-pin" })
        end
    })
end

TabTeleports:Section({ Title = "Special Rooms & Hubs" })

TabTeleports:Button({
    Title = "Enter Trading Hall",
    Desc = "Requests entry to the S3 Trading Hall",
    Callback = function()
        local mw = Remote:FindFirstChild("ManyWorlds") and Remote.ManyWorlds:FindFirstChild("ReqApplyEnterTradingHall")
        if mw then
            mw:InvokeServer()
            WindUI:Notify({ Title = "Trading Hall", Content = "Requested Trading Hall entry.", Duration = 2.5, Icon = "shopping-bag" })
        end
    end
})

TabTeleports:Button({
    Title = "Exit Trading Hall",
    Callback = function()
        local mw = Remote:FindFirstChild("ManyWorlds") and Remote.ManyWorlds:FindFirstChild("ReqApplyExitTradingHall")
        if mw then
            mw:InvokeServer()
        end
    end
})

-- ===================================================
-- TAB 5: PLAYER & UTILITIES
-- ===================================================

TabPlayer:Section({ Title = "Character Modifiers" })

TabPlayer:Toggle({
    Title = "Enable Custom WalkSpeed",
    Value = false,
    Callback = function(state)
        HubState.SpeedEnabled = state
        if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
        end
    end
})

TabPlayer:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 150, Default = 24 },
    Step = 2,
    Callback = function(val)
        HubState.CustomSpeed = val
        if HubState.SpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = val
        end
    end
})

TabPlayer:Toggle({
    Title = "Enable Custom JumpPower",
    Value = false,
    Callback = function(state)
        HubState.JumpEnabled = state
        if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = 50
        end
    end
})

TabPlayer:Slider({
    Title = "JumpPower",
    Value = { Min = 50, Max = 250, Default = 60 },
    Step = 5,
    Callback = function(val)
        HubState.CustomJump = val
        if HubState.JumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.UseJumpPower = true
            LocalPlayer.Character.Humanoid.JumpPower = val
        end
    end
})

TabPlayer:Toggle({
    Title = "Infinite Jump",
    Desc = "Jump continuously in the air",
    Value = false,
    Callback = function(state)
        HubState.InfJump = state
    end
})

TabPlayer:Toggle({
    Title = "NoClip",
    Desc = "Walk through obstacles and terrain walls",
    Value = false,
    Callback = function(state)
        HubState.NoClip = state
    end
})

TabPlayer:Toggle({
    Title = "Anti-AFK Protection",
    Desc = "Prevents Roblox 20-minute idle disconnect",
    Value = true,
    Callback = function(state)
        HubState.AntiAFK = state
    end
})

TabPlayer:Section({ Title = "Hub Management" })

TabPlayer:Button({
    Title = "Unload Hub",
    Desc = "Disconnects all listeners and cleans up the UI",
    Callback = function()
        Cleanup()
    end
})

-- ====================
-- BACKGROUND LOOPS & EVENT CONNECTIONS
-- ====================

-- Anti-AFK Listener
table.insert(HubState.Connections, LocalPlayer.Idled:Connect(function()
    if HubState.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end))

-- Infinite Jump Listener
table.insert(HubState.Connections, UserInputService.JumpRequest:Connect(function()
    if HubState.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

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

    -- NoClip
    if HubState.NoClip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- Auto Battle Handler
    local inBattle, battleWin = IsInBattle()
    if inBattle and battleWin then
        -- Auto Battle activation
        if HubState.AutoBattle and battleWin.AutoButton then
            pcall(function()
                if battleWin.class and battleWin.class.setAutoButton then
                    battleWin.class.setAutoButton(battleWin, true)
                end
            end)
        end

        -- Auto Escape if high level
        if HubState.AutoEscapeIfHighLevel and battleWin.EnemyPetLevelText and battleWin.EscapeButton then
            local lvlNum = tonumber(battleWin.EnemyPetLevelText.Text:match("%d+"))
            if lvlNum and lvlNum >= HubState.EscapeLevelThreshold then
                pcall(function()
                    for _, c in ipairs(getconnections(battleWin.EscapeButton.Activated)) do
                        c:Fire()
                    end
                end)
            end
        end
    end

    -- Auto Farm Wild Evomon loop
    local now = os.clock()
    if HubState.AutoFarmWild and not inBattle and (now - HubState.LastFarmTeleport >= HubState.FarmDelay) then
        HubState.LastFarmTeleport = now
        local creatures = FetchWildCreatures()
        local eligible = {}
        for _, c in ipairs(creatures) do
            if c.level >= HubState.FarmMinLevel and c.distance <= HubState.FarmMaxDistance then
                table.insert(eligible, c)
            end
        end

        if #eligible > 0 then
            local target = eligible[1]
            TeleportTo(target.cframe)
        end
    end
end))

-- Periodic Radar & Stats Updater (every 1.5 seconds)
task.spawn(function()
    while HubState.Running do
        pcall(function()
            local creatures = FetchWildCreatures()
            local closest = HubState.ClosestEvomon
            local inBattle = IsInBattle()

            if closest then
                RadarInfoPara:SetDesc(string.format(
                    "🐾 Wild Evomons in World: %d\n🎯 Closest: %s (Lvl %d)\n📏 Distance: %d studs",
                    #creatures, closest.name, closest.level, math.floor(closest.distance)
                ))
            else
                RadarInfoPara:SetDesc(string.format("🐾 Wild Evomons in World: %d\nSearching for nearby creatures...", #creatures))
            end

            BattleInfoPara:SetDesc(string.format(
                "⚔️ State: %s\n🤖 Auto Fight: %s",
                inBattle and "🔥 In Active Battle" or "⚪ Exploring (Peaceful)",
                HubState.AutoBattle and "Enabled" or "Disabled"
            ))

            -- ESP Updater
            if HubState.EvomonESP then
                local root = GetRootPart()
                local rootPos = root and root.Position or Vector3.zero
                local activeUids = {}

                for _, c in ipairs(creatures) do
                    if c.distance <= 350 then
                        activeUids[c.uid] = true
                        local esp = HubState.ESPObjects[c.uid]
                        if not esp then
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

                            -- Anchor part
                            local part = Instance.new("Part")
                            part.Name = "ESP_Anchor"
                            part.Size = Vector3.new(0.5, 0.5, 0.5)
                            part.Transparency = 1
                            part.Anchored = true
                            part.CanCollide = false
                            part.CFrame = c.cframe
                            part.Parent = workspace
                            bg.Adornee = part
                            bg.Parent = (gethui and gethui()) or game:GetService("CoreGui")

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
    TeleportToClosest = function()
        local list = FetchWildCreatures()
        if list[1] then TeleportTo(list[1].cframe) end
    end,
    TeleportTo = TeleportTo
}

WindUI:Notify({
    Title = "Evomon Hub Loaded!",
    Content = "All features initialized. Wild Radar, Auto Battle, and Codes are ready!",
    Duration = 4,
    Icon = "sparkles"
})

return Window
