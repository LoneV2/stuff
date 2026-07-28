local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")

local genRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Generator")
local skillResultRemote = genRemotes and genRemotes:FindFirstChild("SkillCheckResultEvent")

local origLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd
}

local Settings = {
    GenESP = true,
    GenHighlightEnabled = true,
    GenBillboardEnabled = true,
    GenOutlineColor = Color3.fromRGB(255, 140, 0),
    GenCompleteColor = Color3.fromRGB(46, 204, 113),

    PlayerESP = true,
    PlayerHighlightEnabled = true,
    PlayerBillboardEnabled = true,
    Fullbright = false,

    AutoSkillCheck = true,
    SkillCheckMode = "great"
}

-- Lighting Manager
local function updateLighting()
    if Settings.Fullbright then
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.Brightness = 2.0
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1000000
    else
        Lighting.Ambient = origLighting.Ambient
        Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
        Lighting.Brightness = origLighting.Brightness
        Lighting.GlobalShadows = origLighting.GlobalShadows
        Lighting.FogEnd = origLighting.FogEnd
    end
end

Lighting.Changed:Connect(function()
    if Settings.Fullbright then
        updateLighting()
    end
end)

local function isKiller(player)
    if not player then return false end

    if player.Team then
        local teamName = player.Team.Name:lower()
        if teamName:find("killer") or teamName:find("scourge") or teamName:find("hunter") or teamName:find("monster") then
            return true
        end
        if teamName:find("survivor") then
            return false
        end
    end

    if player:GetAttribute("IsKiller") == true then
        return true
    end

    local role = player:GetAttribute("Role")
    if role then
        local roleStr = tostring(role):lower()
        if roleStr == "killer" or roleStr:find("killer") or roleStr:find("scourge") then
            return true
        end
        if roleStr == "survivor" then
            return false
        end
    end

    if player.Character then
        if player.Character:GetAttribute("IsKiller") == true then
            return true
        end
        local charRole = player.Character:GetAttribute("Role")
        if charRole and tostring(charRole):lower():find("killer") then
            return true
        end
    end

    return false
end

local function isKingScourgeActive()
    for _, p in ipairs(Players:GetPlayers()) do
        local sel = tostring(p:GetAttribute("SelectedKiller") or ""):lower()
        local role = tostring(p:GetAttribute("Role") or ""):lower()
        if sel:find("scourge") or sel:find("king") or role:find("scourge") or role:find("king") then
            return true
        end
        if p.Character then
            local charName = p.Character.Name:lower()
            if charName:find("scourge") or charName:find("king") then
                return true
            end
        end
    end

    for _, obj in ipairs(Workspace:GetChildren()) do
        local n = obj.Name:lower()
        if n:find("scourge") or n:find("king") then
            return true
        end
    end

    local promptGui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
    if promptGui then
        for _, v in ipairs(promptGui:GetDescendants()) do
            local vn = v.Name:lower()
            if vn:find("scourge") or vn:find("reverse") or vn:find("king") then
                return true
            end
        end
    end

    return false
end

local function getHealthColor(humanoid)
    if not humanoid then return Color3.fromRGB(46, 204, 113) end
    local maxHp = math.max(humanoid.MaxHealth, 1)
    local hpPct = math.clamp(humanoid.Health / maxHp, 0, 1)

    if hpPct >= 0.7 then
        return Color3.fromRGB(46, 204, 113)
    elseif hpPct >= 0.35 then
        return Color3.fromRGB(255, 140, 0)
    else
        return Color3.fromRGB(230, 50, 50)
    end
end

local function getPlayerOutlineColor(player, humanoid)
    if isKiller(player) then
        return Color3.fromRGB(255, 0, 0)
    end
    return getHealthColor(humanoid)
end

local function forceUnstickCharacter()
    if localPlayer.Character then
        local char = localPlayer.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum.PlatformStand = false
            hum.AutoRotate = true
        end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("AlignPosition") or child:IsA("AlignOrientation") or child:IsA("WeldConstraint") then
                if child.Name:lower():find("repair") or child.Name:lower():find("gen") or child.Name:lower():find("skill") then
                    child:Destroy()
                end
            end
        end
    end
end

local activeGenerators = {}
local activePlayers = {}

local function updateAllGeneratorsESP()
    for _, data in pairs(activeGenerators) do
        if data.Highlight and data.Highlight.Parent then
            data.Highlight.Enabled = Settings.GenESP and Settings.GenHighlightEnabled
        end
        if data.Billboard and data.Billboard.Parent then
            data.Billboard.Enabled = Settings.GenESP and Settings.GenBillboardEnabled
        end
    end
end

local function updateAllPlayersESP()
    for _, data in pairs(activePlayers) do
        if data.Highlight and data.Highlight.Parent then
            data.Highlight.Enabled = Settings.PlayerESP and Settings.PlayerHighlightEnabled
        end
        if data.Billboard and data.Billboard.Parent then
            data.Billboard.Enabled = Settings.PlayerESP and Settings.PlayerBillboardEnabled
        end
    end
end

-- Rayfield Window Setup
local Window = Rayfield:CreateWindow({
    Name = "Hzyl VD",
    LoadingTitle = "Hzyl HUB",
    LoadingSubtitle = "vibecoded using Gemini",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

local GenTab = Window:CreateTab("Generators", 4483362458)
local PlayerTab = Window:CreateTab("Players", 4483362458)
local InfoTab = Window:CreateTab("Info", 4483362458)

-- Generator Tab Elements
GenTab:CreateToggle({
    Name = "Master Generator ESP",
    CurrentValue = Settings.GenESP,
    Flag = "GenESP",
    Callback = function(Value)
        Settings.GenESP = Value
        updateAllGeneratorsESP()
    end,
})

GenTab:CreateToggle({
    Name = "Generator Highlights",
    CurrentValue = Settings.GenHighlightEnabled,
    Flag = "GenHighlightEnabled",
    Callback = function(Value)
        Settings.GenHighlightEnabled = Value
        updateAllGeneratorsESP()
    end,
})

GenTab:CreateToggle({
    Name = "Generator Progress",
    CurrentValue = Settings.GenBillboardEnabled,
    Flag = "GenBillboardEnabled",
    Callback = function(Value)
        Settings.GenBillboardEnabled = Value
        updateAllGeneratorsESP()
    end,
})

GenTab:CreateToggle({
    Name = "Auto SkillCheck",
    CurrentValue = Settings.AutoSkillCheck,
    Flag = "AutoSkillCheck",
    Callback = function(Value)
        Settings.AutoSkillCheck = Value
    end,
})

GenTab:CreateToggle({
    Name = "Perfect Skillcheck (+1% Progress)",
    CurrentValue = (Settings.SkillCheckMode == "great"),
    Flag = "SkillCheckMode",
    Callback = function(Value)
        Settings.SkillCheckMode = Value and "great" or "good"
    end,
})

GenTab:CreateButton({
    Name = "UNSTICK CHARACTER",
    Callback = function()
        forceUnstickCharacter()
    end,
})

-- Players Tab Elements
PlayerTab:CreateToggle({
    Name = "Master Player ESP",
    CurrentValue = Settings.PlayerESP,
    Flag = "PlayerESP",
    Callback = function(Value)
        Settings.PlayerESP = Value
        updateAllPlayersESP()
    end,
})

PlayerTab:CreateToggle({
    Name = "Player Highlights",
    CurrentValue = Settings.PlayerHighlightEnabled,
    Flag = "PlayerHighlightEnabled",
    Callback = function(Value)
        Settings.PlayerHighlightEnabled = Value
        updateAllPlayersESP()
    end,
})

PlayerTab:CreateToggle({
    Name = "Player Names",
    CurrentValue = Settings.PlayerBillboardEnabled,
    Flag = "PlayerBillboardEnabled",
    Callback = function(Value)
        Settings.PlayerBillboardEnabled = Value
        updateAllPlayersESP()
    end,
})

PlayerTab:CreateToggle({
    Name = "Soft Fullbright",
    CurrentValue = Settings.Fullbright,
    Flag = "Fullbright",
    Callback = function(Value)
        Settings.Fullbright = Value
        updateLighting()
    end,
})

-- Info Tab Section & Dynamic Single-Paragraph Update
InfoTab:CreateSection("ACTIVE LOADOUTS")

local InfoParagraph = InfoTab:CreateParagraph({
    Title = "MATCH STATS",
    Content = "Loading active match data..."
})

InfoTab:CreateSection("CREDITS")
InfoTab:CreateParagraph({
    Title = "⚡ VIBECODED USING GEMINI",
    Content = "hzyl HUB for Violence District"
})

local function refreshInfoTab()
    local textLines = {}

    for _, p in ipairs(Players:GetPlayers()) do
        local isKill = isKiller(p)
        local itemStr = p:GetAttribute("EquippedItem") or "None"
        
        if itemStr == "None" and p.Character then
            local tool = p.Character:FindFirstChildOfClass("Tool")
            if tool then
                itemStr = tool.Name
            end
        end

        local killerStr = p:GetAttribute("SelectedKiller") or (isKill and "King Scourge" or "Standard")
        local lvl = p:GetAttribute("Level") or 1

        local pName = string.upper(p.Name)
        if isKill then
            table.insert(textLines, "🔴 " .. pName .. "\n   • SELECTED: " .. string.upper(tostring(killerStr)) .. "\n   • LEVEL: " .. tostring(lvl))
        else
            table.insert(textLines, "🔵 " .. pName .. "\n   • ITEM: " .. string.upper(tostring(itemStr)) .. "\n   • LEVEL: " .. tostring(lvl))
        end
    end

    InfoParagraph:Set({
        Title = "CURRENT MATCH LOADOUTS",
        Content = table.concat(textLines, "\n\n")
    })
end

refreshInfoTab()
Players.PlayerAdded:Connect(refreshInfoTab)
Players.PlayerRemoving:Connect(refreshInfoTab)

-- Event-Driven Player ESP Logic
local function removePlayerESP(player)
    if activePlayers[player] then
        local data = activePlayers[player]
        if data.Highlight and data.Highlight.Parent then data.Highlight:Destroy() end
        if data.Billboard and data.Billboard.Parent then data.Billboard:Destroy() end
        if data.Conns then
            for _, conn in ipairs(data.Conns) do conn:Disconnect() end
        end
        activePlayers[player] = nil
    end
end

local function setupPlayer(player)
    if player == localPlayer then return end

    local function onCharacterAdded(character)
        removePlayerESP(player)

        local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoidRootPart or not humanoid then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillTransparency = 0.85
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = character
        highlight.Enabled = Settings.PlayerESP and Settings.PlayerHighlightEnabled
        highlight.Parent = character

        local nameBillboard = Instance.new("BillboardGui")
        nameBillboard.Name = "ESPNameBillboard"
        nameBillboard.Size = UDim2.new(0, 120, 0, 16)
        nameBillboard.StudsOffset = Vector3.new(0, 3, 0)
        nameBillboard.AlwaysOnTop = true
        nameBillboard.Enabled = Settings.PlayerESP and Settings.PlayerBillboardEnabled
        nameBillboard.Parent = humanoidRootPart

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextStrokeTransparency = 0
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.TextSize = 10
        nameLabel.TextXAlignment = Enum.TextXAlignment.Center

        if isKiller(player) then
            nameLabel.Text = "[KILLER] " .. player.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
        else
            nameLabel.Text = player.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        nameLabel.Parent = nameBillboard

        local data = {
            Highlight = highlight,
            Billboard = nameBillboard,
            Conns = {}
        }
        activePlayers[player] = data

        local function updateColor()
            if highlight and highlight.Parent then
                local col = getPlayerOutlineColor(player, humanoid)
                highlight.OutlineColor = col
                highlight.FillColor = col
            end
        end
        updateColor()

        local hpConn = humanoid:GetPropertyChangedSignal("Health"):Connect(updateColor)
        table.insert(data.Conns, hpConn)

        local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            updateColor()
            if isKiller(player) then
                nameLabel.Text = "[KILLER] " .. player.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
            else
                nameLabel.Text = player.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
            refreshInfoTab()
        end)
        table.insert(data.Conns, teamConn)

        local charAncestry = character.AncestryChanged:Connect(function(_, parent)
            if not parent then removePlayerESP(player) end
        end)
        table.insert(data.Conns, charAncestry)
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    removePlayerESP(player)
    refreshInfoTab()
end)

-- Generator setup logic
local function removeGeneratorESP(generator)
    if activeGenerators[generator] then
        local data = activeGenerators[generator]
        if data.Highlight and data.Highlight.Parent then data.Highlight:Destroy() end
        if data.Billboard and data.Billboard.Parent then data.Billboard:Destroy() end
        if data.Conns then
            for _, conn in ipairs(data.Conns) do conn:Disconnect() end
        end
        activeGenerators[generator] = nil
    end
end

local function getProgressPercentage(generator)
    local progress = generator:GetAttribute("RepairProgress") 
        or generator:GetAttribute("Progress") 
        or generator:GetAttribute("Completion") 
        or 0
        
    if type(progress) == "number" then
        if progress > 0 and progress <= 1 then
            return math.floor(progress * 100)
        else
            return math.floor(math.clamp(progress, 0, 100))
        end
    end
    return 0
end

local function setupGenerator(generator)
    if not generator:IsA("Model") then return end
    if not (generator.Name == "Generator" or generator.Name:lower():find("generator")) then return end
    if activeGenerators[generator] then return end

    task.defer(function()
        if not generator.Parent then return end

        local targetPart = generator.PrimaryPart 
            or generator:FindFirstChild("RootPart") 
            or generator:FindFirstChild("HitBox") 
            or generator:FindFirstChildWhichIsA("BasePart")

        if not targetPart then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillTransparency = 0.85
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.OutlineColor = Settings.GenOutlineColor
        highlight.Adornee = generator
        highlight.Parent = generator

        local _, size = generator:GetBoundingBox()
        local topOffset = (size.Y / 2) + 0.8

        local bb = Instance.new("BillboardGui")
        bb.Name = "ESPGenBillboard"
        bb.Size = UDim2.new(0, 140, 0, 26)
        bb.StudsOffset = Vector3.new(0, topOffset, 0)
        bb.AlwaysOnTop = true
        bb.Parent = targetPart

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Settings.GenOutlineColor
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.FredokaOne
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.Parent = bb

        local data = {
            Generator = generator,
            Highlight = highlight,
            Billboard = bb,
            Label = label,
            Conns = {}
        }
        activeGenerators[generator] = data

        local function updateProgress()
            if label and generator.Parent then
                local pct = getProgressPercentage(generator)
                local playersCount = generator:GetAttribute("PlayersRepairingCount") or 0

                label.Text = pct .. "% [" .. playersCount .. "]"
                highlight.Enabled = Settings.GenESP and Settings.GenHighlightEnabled
                bb.Enabled = Settings.GenESP and Settings.GenBillboardEnabled

                if pct >= 100 then
                    label.TextColor3 = Settings.GenCompleteColor
                    highlight.OutlineColor = Settings.GenCompleteColor
                else
                    label.TextColor3 = Settings.GenOutlineColor
                    highlight.OutlineColor = Settings.GenOutlineColor
                end
            end
        end

        local conn = generator.AttributeChanged:Connect(updateProgress)
        table.insert(data.Conns, conn)

        local ancConn = generator.AncestryChanged:Connect(function(_, parent)
            if not parent then removeGeneratorESP(generator) end
        end)
        table.insert(data.Conns, ancConn)

        updateProgress()
    end)
end

for _, item in ipairs(Workspace:GetDescendants()) do
    if item:IsA("Model") and (item.Name == "Generator" or item.Name:lower():find("generator")) then
        setupGenerator(item)
    end
end
Workspace.DescendantAdded:Connect(function(item)
    if item:IsA("Model") and (item.Name == "Generator" or item.Name:lower():find("generator")) then
        setupGenerator(item)
    end
end)
Workspace.DescendantRemoving:Connect(function(item)
    if activeGenerators[item] then removeGeneratorESP(item) end
end)

-- Skillcheck logic
local promptGui = PlayerGui:WaitForChild("SkillCheckPromptGui", 5)
if promptGui then
    local check = promptGui:WaitForChild("Check", 5)
    local line = check and check:WaitForChild("Line", 5)
    local goal = check and check:WaitForChild("Goal", 5)

    if check and line and goal then
        local handledThisPrompt = false

        promptGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not promptGui.Enabled then
                handledThisPrompt = false
            end
        end)

        check:GetPropertyChangedSignal("Visible"):Connect(function()
            if not check.Visible then
                handledThisPrompt = false
            end
        end)

        RunService.RenderStepped:Connect(function()
            if check.Visible and Settings.AutoSkillCheck then
                if isKingScourgeActive() then
                    if not handledThisPrompt then
                        local lineRot = line.AbsoluteRotation % 360
                        local goalRot = goal.AbsoluteRotation % 360
                        local targetAngle = (goalRot + (Settings.SkillCheckMode == "great" and 5 or 12)) % 360

                        local diff = math.abs((lineRot - targetAngle + 180) % 360 - 180)

                        if diff <= 16 then
                            handledThisPrompt = true
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                            task.wait(0.015)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        end
                    end
                else
                    if not handledThisPrompt then
                        handledThisPrompt = true
                        local offset = (Settings.SkillCheckMode == "great") and 109 or 130
                        line.Rotation = (goal.Rotation + offset)

                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

                        if skillResultRemote then
                            pcall(function()
                                skillResultRemote:FireServer("success", 1)
                            end)
                        end
                    end
                end
            end
        end)
    end
end

task.spawn(function()
    while task.wait(0.5) do
        if localPlayer.Character then
            local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed == 0 then
                forceUnstickCharacter()
            end
        end
    end
end)
