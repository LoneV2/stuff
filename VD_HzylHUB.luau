-- Made by hzyl (GUI-less Ultra-Fast Edition)

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

-- Configured Headless Settings (All Auto Active, Fullbright Excluded)
local Settings = {
    GenESP = true,
    GenHighlightEnabled = true,
    GenBillboardEnabled = true,
    GenOutlineColor = Color3.fromRGB(255, 140, 0),
    GenCompleteColor = Color3.fromRGB(46, 204, 113),

    PlayerESP = true,
    PlayerHighlightEnabled = true,
    PlayerBillboardEnabled = true,

    AutoSkillCheck = true,
    SkillCheckMode = "great"
}

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

local activeGenerators = {}
local activePlayers = {}

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
        nameBillboard.Size = UDim2.new(0, 180, 0, 26)
        nameBillboard.StudsOffset = Vector3.new(0, 3.4, 0)
        nameBillboard.AlwaysOnTop = true
        nameBillboard.Enabled = Settings.PlayerESP and Settings.PlayerBillboardEnabled
        nameBillboard.Parent = humanoidRootPart

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.TextSize = 16
        nameLabel.TextXAlignment = Enum.TextXAlignment.Center

        nameLabel.Text = player.Name
        if isKiller(player) then
            nameLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
        else
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
            nameLabel.Text = player.Name
            if isKiller(player) then
                nameLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
            else
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
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
end)

-- Generator Setup Logic (Event-Driven)
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

-- Initial Generator Registration
for _, item in ipairs(Workspace:GetDescendants()) do
    if item:IsA("Model") and (item.Name == "Generator" or item.Name:lower():find("generator")) then
        setupGenerator(item)
    end
end

-- Event Listeners for Generator Spawns
Workspace.DescendantAdded:Connect(function(item)
    if item:IsA("Model") and (item.Name == "Generator" or item.Name:lower():find("generator")) then
        setupGenerator(item)
    end
end)

Workspace.DescendantRemoving:Connect(function(item)
    if activeGenerators[item] then removeGeneratorESP(item) end
end)

-- Ultra-Fast Instant-Trigger SkillCheck Engine
local boundPrompts = {}

local function setupSkillCheckGui(promptGui)
    if not promptGui or boundPrompts[promptGui] then return end
    boundPrompts[promptGui] = true

    task.spawn(function()
        local check = promptGui:FindFirstChild("Check") or promptGui:WaitForChild("Check", 10)
        local line = check and (check:FindFirstChild("Line") or check:WaitForChild("Line", 10))
        local goal = check and (check:FindFirstChild("Goal") or check:WaitForChild("Goal", 10))

        if not (check and line and goal) then return end

        local handledThisPrompt = false

        local function resetPromptState()
            handledThisPrompt = false
        end

        local function sendServerSkillSuccess()
            local genRemotesNow = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Generator")
            local currentSkillRemote = genRemotesNow and genRemotesNow:FindFirstChild("SkillCheckResultEvent") or skillResultRemote
            if currentSkillRemote then
                pcall(function()
                    currentSkillRemote:FireServer("success", 1)
                end)
            end
        end

        local function processInstantCheck()
            if not (check.Visible and promptGui.Enabled and Settings.AutoSkillCheck) then
                handledThisPrompt = false
                return
            end

            if handledThisPrompt then return end

            if isKingScourgeActive() then
                local lineRot = line.AbsoluteRotation % 360
                local goalRot = goal.AbsoluteRotation % 360
                local targetAngle = (goalRot + (Settings.SkillCheckMode == "great" and 5 or 12)) % 360

                local diff = math.abs((lineRot - targetAngle + 180) % 360 - 180)

                if diff <= 28 then
                    handledThisPrompt = true
                    
                    line.Rotation = (goal.Rotation + ((Settings.SkillCheckMode == "great") and 5 or 12))
                    
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.025)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                    
                    sendServerSkillSuccess()
                    task.delay(0.2, resetPromptState)
                end
            else
                handledThisPrompt = true
                local offset = (Settings.SkillCheckMode == "great") and 109 or 130
                line.Rotation = (goal.Rotation + offset)

                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.025)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

                sendServerSkillSuccess()
                task.delay(0.2, resetPromptState)
            end
        end

        -- Direct Instant Trigger on Event Signal + RenderStepped Fallback
        promptGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        check:GetPropertyChangedSignal("Visible"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        goal:GetPropertyChangedSignal("Rotation"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        check:GetPropertyChangedSignal("Rotation"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        local renderConn
        renderConn = RunService.RenderStepped:Connect(function()
            if not promptGui.Parent then
                if renderConn then renderConn:Disconnect() end
                boundPrompts[promptGui] = nil
                return
            end
            processInstantCheck()
        end)

        processInstantCheck()
    end)
end

-- Bind existing & future SkillCheck GUIs
local existingPrompt = PlayerGui:FindFirstChild("SkillCheckPromptGui")
if existingPrompt then setupSkillCheckGui(existingPrompt) end

PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "SkillCheckPromptGui" or child.Name:lower():find("skillcheck") then
        setupSkillCheckGui(child)
    end
end)
