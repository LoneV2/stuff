-- HzylHUB

if getgenv().HzylHUB_Cleanup then
    pcall(getgenv().HzylHUB_Cleanup)
end

for _, item in ipairs(workspace:GetDescendants()) do
    if item:IsA("Highlight") and (item.Name == "ESPHighlight" or item.Name == "ZombieESPHighlight" or item.Name == "ExitGateHighlight") then
        pcall(function() item:Destroy() end)
    elseif item:IsA("BillboardGui") and (item.Name == "ESPGenBillboard" or item.Name == "ESPNameBillboard" or item.Name == "ESPExitBillboard") then
        pcall(function() item:Destroy() end)
    elseif item:IsA("ScreenGui") and (item.Name == "HzylHUB_CrosshairGui" or item.Name == "HzylHUB_KillerInfoGui") then
        pcall(function() item:Destroy() end)
    end
end

local Connections = {}
local ObjectsToDestroy = {}
local DrawingsToDestroy = {}
local Threads = {}

getgenv().HzylHUB_Cleanup = function()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)

    for _, thr in ipairs(Threads) do
        pcall(task.cancel, thr)
    end
    table.clear(Threads)

    for _, draw in ipairs(DrawingsToDestroy) do
        pcall(function() draw:Remove() end)
    end
    table.clear(DrawingsToDestroy)

    for obj, _ in pairs(ObjectsToDestroy) do
        pcall(function() if obj and obj.Parent then obj:Destroy() end end)
    end
    table.clear(ObjectsToDestroy)
end

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")

local genRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Generator")
local skillResultRemote = genRemotes and genRemotes:FindFirstChild("SkillCheckResultEvent")
local perkRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Perks")
local perfRemote = perkRemotes and perkRemotes:FindFirstChild("perfectionistplanning")
local repairAnimRemote = genRemotes and genRemotes:FindFirstChild("RepairAnim")
local escapeTimeRemote = genRemotes and genRemotes:FindFirstChild("Escapetime")
local leverAnimRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Exit") and ReplicatedStorage.Remotes.Exit:FindFirstChild("LeverAnim")

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "HzylHUB",
        Text = "Loaded",
        Duration = 2
    })
end)

local Settings = {
    GenESP = true,
    GenHighlightEnabled = true,
    GenBillboardEnabled = true,
    GenNormalColor = Color3.fromRGB(255, 140, 0),
    GenPerkColor = Color3.fromRGB(255, 230, 0),
    GenCompleteColor = Color3.fromRGB(46, 204, 113),

    ExitLeverESP = true,
    ExitLeverColor = Color3.fromRGB(46, 204, 113),

    PlayerESP = true,
    PlayerHighlightEnabled = true,
    PlayerBillboardEnabled = true,
    SurvivorHealthyColor = Color3.fromRGB(50, 170, 255),

    ZombieESP = true,
    ZombieAwakeColor = Color3.fromRGB(170, 0, 255),
    ZombieDormantColor = Color3.fromRGB(80, 80, 80),

    AutoSkillCheck = true,
    SkillCheckMode = "great",

    AlwaysPerfectionistBoost = true,

    Crosshair = {
        enabled = true,
        color = Color3.fromRGB(57, 255, 20),
        dot_size = 5,
        x_offset = 0,
        y_offset = 0
    }
}

-- Crosshair (Mobile & PC Universal)
if Settings.Crosshair.enabled then
    local crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "HzylHUB_CrosshairGui"
    crosshairGui.ResetOnSpawn = false
    crosshairGui.IgnoreGuiInset = true

    pcall(function()
        if gethui then
            crosshairGui.Parent = gethui()
        else
            crosshairGui.Parent = PlayerGui
        end
    end)
    if not crosshairGui.Parent then crosshairGui.Parent = PlayerGui end
    ObjectsToDestroy[crosshairGui] = true

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0.5, Settings.Crosshair.x_offset, 0.5, Settings.Crosshair.y_offset)
    dot.Size = UDim2.new(0, Settings.Crosshair.dot_size, 0, Settings.Crosshair.dot_size)
    dot.BackgroundColor3 = Settings.Crosshair.color
    dot.BorderSizePixel = 0
    dot.Parent = crosshairGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot
end

local cachedPerkEquipped = false
local activeGenerators = {}
local activeZombies = {}
local activePlayers = {}
local activeLevers = {}
local killerCache = {}
local cachedKingScourge = nil
local lastKingCheck = 0
local gatesPoweredFlag = false

if escapeTimeRemote then
    local cEsc = escapeTimeRemote.OnClientEvent:Connect(function()
        gatesPoweredFlag = true
        for _, data in pairs(activeLevers) do
            if data.Update then data.Update() end
        end
    end)
    table.insert(Connections, cEsc)
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

local function areGatesPowered()
    if gatesPoweredFlag then return true end

    local completed = 0
    for gen, _ in pairs(activeGenerators) do
        if gen and gen.Parent then
            local pct = getProgressPercentage(gen)
            if pct >= 100 or gen:GetAttribute("Completed") == true then
                completed = completed + 1
            end
        end
    end

    if completed >= 5 then
        gatesPoweredFlag = true
        return true
    end

    local survGen = PlayerGui:FindFirstChild("Survivor") and PlayerGui.Survivor:FindFirstChild("Gen")
    if survGen then
        local runImg = survGen:FindFirstChild("run")
        if runImg and runImg.ImageTransparency == 0 then
            gatesPoweredFlag = true
            return true
        end
    end

    return false
end

local function checkPerkEquipped()
    local char = localPlayer.Character
    if char then
        if char:GetAttribute("perfectionistplanning") ~= nil or char:GetAttribute("PerfectionistPlanning") ~= nil then
            return true
        end
        if char:FindFirstChild("perfectionist") or char:FindFirstChild("perfectionistplanning") then
            return true
        end
    end

    local survPerks = PlayerGui:FindFirstChild("SurvivorPerks")
    if survPerks then
        for _, parentFrame in ipairs({survPerks:FindFirstChild("Perks"), survPerks:FindFirstChild("Perksmob")}) do
            if parentFrame then
                for _, child in ipairs(parentFrame:GetChildren()) do
                    local cName = child.Name:lower()
                    if cName:find("perfectionist") or cName:find("planning") then
                        return true
                    end
                end
            end
        end
    end

    if workspace:FindFirstChild(localPlayer.Name) and workspace[localPlayer.Name]:FindFirstChild("perfectionist") then
        return true
    end

    return false
end

local function updatePerkState()
    cachedPerkEquipped = checkPerkEquipped()
    for _, data in pairs(activeGenerators) do
        if data.Update then
            data.Update()
        end
    end
end

local function getCachedGeneratorsList()
    local list = {}
    for gen, _ in pairs(activeGenerators) do
        if gen and gen.Parent then
            table.insert(list, gen)
        end
    end
    return list
end

local function forcePerfectionistBoost()
    if not (Settings.AlwaysPerfectionistBoost and perfRemote and cachedPerkEquipped) then return end
    pcall(function()
        perfRemote:FireServer("applyBoost", "fast")
        perfRemote:FireServer("broadcast", getCachedGeneratorsList())
    end)
end

if hookmetamethod and not getgenv().HzylHUB_NamecallHooked then
    getgenv().HzylHUB_NamecallHooked = true
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" and self and self.Name == "perfectionistplanning" and Settings.AlwaysPerfectionistBoost and cachedPerkEquipped then
            if args[1] == "applyBoost" then
                args[2] = "fast"
                return oldNamecall(self, unpack(args))
            end
        end

        return oldNamecall(self, ...)
    end)
end

if repairAnimRemote then
    local cRep = repairAnimRemote.OnClientEvent:Connect(function(_, isRepairing)
        if isRepairing and Settings.AlwaysPerfectionistBoost and cachedPerkEquipped then
            forcePerfectionistBoost()
        end
    end)
    table.insert(Connections, cRep)
end

-- Skill Check
local boundPrompts = {}

local function isKingScourgeActive()
    local now = os.clock()
    if cachedKingScourge ~= nil and (now - lastKingCheck < 3) then
        return cachedKingScourge
    end
    lastKingCheck = now

    for _, p in ipairs(Players:GetPlayers()) do
        local sel = tostring(p:GetAttribute("SelectedKiller") or ""):lower()
        local role = tostring(p:GetAttribute("Role") or ""):lower()
        if sel:find("scourge") or sel:find("king") or role:find("scourge") or role:find("king") then
            cachedKingScourge = true
            return true
        end
        if p.Character then
            local charName = p.Character.Name:lower()
            if charName:find("scourge") or charName:find("king") then
                cachedKingScourge = true
                return true
            end
        end
    end

    for _, obj in ipairs(Workspace:GetChildren()) do
        local n = obj.Name:lower()
        if n:find("scourge") or n:find("king") then
            cachedKingScourge = true
            return true
        end
    end

    cachedKingScourge = false
    return false
end

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

        local processInstantCheck = function()
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

        local c1 = promptGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        local c2 = check:GetPropertyChangedSignal("Visible"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        local c3 = goal:GetPropertyChangedSignal("Rotation"):Connect(function()
            resetPromptState()
            processInstantCheck()
        end)

        local c4 = check:GetPropertyChangedSignal("Rotation"):Connect(function()
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

        table.insert(Connections, c1)
        table.insert(Connections, c2)
        table.insert(Connections, c3)
        table.insert(Connections, c4)
        table.insert(Connections, renderConn)

        processInstantCheck()
    end)
end

-- Players
local function isKiller(player)
    if not player then return false end
    if killerCache[player] ~= nil then return killerCache[player] end

    local isK = false
    if player.Team then
        local teamName = player.Team.Name:lower()
        if teamName:find("killer") or teamName:find("scourge") or teamName:find("hunter") or teamName:find("monster") then
            isK = true
        end
        if teamName:find("survivor") then isK = false end
    end

    if not isK and player:GetAttribute("IsKiller") == true then isK = true end

    if not isK then
        local role = player:GetAttribute("Role")
        if role then
            local roleStr = tostring(role):lower()
            if roleStr == "killer" or roleStr:find("killer") or roleStr:find("scourge") then isK = true end
            if roleStr == "survivor" then isK = false end
        end
    end

    if not isK and player.Character then
        if player.Character:GetAttribute("IsKiller") == true then isK = true end
        local charRole = player.Character:GetAttribute("Role")
        if charRole and tostring(charRole):lower():find("killer") then isK = true end
    end

    killerCache[player] = isK
    return isK
end

local function getKillerInfo()
    for _, p in ipairs(Players:GetPlayers()) do
        if isKiller(p) then
            local killerType = p:GetAttribute("SelectedKiller") or p:GetAttribute("Killer")
            if not killerType and p.Character then
                killerType = p.Character:GetAttribute("SelectedKiller") or p.Character:GetAttribute("Killer")
            end
            if not killerType or killerType == "" then
                killerType = "Killer"
            end
            return p.DisplayName .. "(" .. p.Name .. ") [" .. tostring(killerType) .. "]"
        end
    end
    return "None"
end

local function getHealthColor(humanoid)
    if not humanoid then return Settings.SurvivorHealthyColor end
    local maxHp = math.max(humanoid.MaxHealth, 1)
    local hpPct = math.clamp(humanoid.Health / maxHp, 0, 1)

    if hpPct >= 0.7 then
        return Settings.SurvivorHealthyColor
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

-- Killer HUD (Bottom-Right)
local killerGui = Instance.new("ScreenGui")
killerGui.Name = "HzylHUB_KillerInfoGui"
killerGui.ResetOnSpawn = false

pcall(function()
    if gethui then
        killerGui.Parent = gethui()
    else
        killerGui.Parent = PlayerGui
    end
end)
if not killerGui.Parent then killerGui.Parent = PlayerGui end
ObjectsToDestroy[killerGui] = true

local killerLabel = Instance.new("TextLabel")
killerLabel.Name = "KillerLabel"
killerLabel.AnchorPoint = Vector2.new(1, 1)
killerLabel.Position = UDim2.new(1, -15, 1, -15)
killerLabel.Size = UDim2.new(0, 450, 0, 24)
killerLabel.BackgroundTransparency = 1
killerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
killerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
killerLabel.TextStrokeTransparency = 0
killerLabel.Font = Enum.Font.FredokaOne
killerLabel.TextSize = 14
killerLabel.RichText = true
killerLabel.TextXAlignment = Enum.TextXAlignment.Right
killerLabel.TextYAlignment = Enum.TextYAlignment.Bottom
killerLabel.Parent = killerGui

local function updateKillerLabel()
    if killerLabel and killerLabel.Parent then
        local kInfo = getKillerInfo()
        if kInfo == "None" then
            killerLabel.Text = 'Killer: <font color="rgb(180, 180, 180)">None</font>'
        else
            killerLabel.Text = 'Killer: <font color="rgb(255, 75, 75)">' .. kInfo .. '</font>'
        end
    end
end
updateKillerLabel()

-- Zombie ESP
local function isZombieCandidate(model)
    if not (model and model:IsA("Model")) then return false end
    if Players:GetPlayerFromCharacter(model) then return false end

    local name = model.Name:lower()
    if name:find("generator") or name:find("gate") or name:find("lever") or name:find("pallet") or name:find("hook") then
        return false
    end

    if name:find("zombie") or name:find("scp") or name:find("049") or name:find("walker") 
       or name:find("corpse") or name:find("infected") or name:find("minion") or name:find("undead") 
       or name:find("ghoul") or name:find("patient") or name:find("crawler") or name:find("reanimated") then
        return true
    end

    if model:GetAttribute("IsZombie") ~= nil or model:GetAttribute("Zombie") ~= nil or model:GetAttribute("Corpse") ~= nil then
        return true
    end

    return false
end

local function removeZombieESP(zombie)
    local data = activeZombies[zombie]
    if data then
        if data.Highlight and data.Highlight.Parent then data.Highlight:Destroy() end
        for _, conn in ipairs(data.Conns or {}) do conn:Disconnect() end
        activeZombies[zombie] = nil
    end
end

local function isZombieAwake(zombie)
    if not (zombie and zombie.Parent) then return false end
    local hum = zombie:FindFirstChildWhichIsA("Humanoid")
    local hrp = zombie:FindFirstChild("HumanoidRootPart") or zombie.PrimaryPart or zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso")
    
    if hum and hum.Health <= 0 then return false end

    if zombie:GetAttribute("Awake") == true or zombie:GetAttribute("Active") == true then return true end
    if zombie:GetAttribute("Dormant") == true or zombie:GetAttribute("Dead") == true or zombie:GetAttribute("Downed") == true or zombie:GetAttribute("Sleeping") == true then
        return false
    end

    if zombie:FindFirstChild("Dormant") or zombie:FindFirstChild("Ragdoll") or zombie:FindFirstChild("Dead") or zombie:FindFirstChild("Knocked") then
        return false
    end

    if hum then
        if hum.Sit or hum.PlatformStand then
            return false
        end
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Seated then
            return false
        end
    end

    if hrp then
        if hrp.CFrame.UpVector.Y < 0.5 then
            return false
        end
    end

    local name = zombie.Name:lower()
    if (name:find("corpse") or name:find("patient")) and (not hrp or hrp.CFrame.UpVector.Y < 0.6) then
        return false
    end

    return true
end

local function setupZombie(zombie)
    if not isZombieCandidate(zombie) or activeZombies[zombie] then return end

    task.spawn(function()
        local hum = zombie:FindFirstChildWhichIsA("Humanoid") or zombie:WaitForChild("Humanoid", 3)
        if not zombie.Parent then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ZombieESPHighlight"
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = zombie
        highlight.Parent = zombie

        ObjectsToDestroy[highlight] = true

        local data = { Zombie = zombie, Highlight = highlight, Conns = {} }
        activeZombies[zombie] = data

        local lastAwake = nil

        local function updateZombieState()
            if not (highlight and zombie.Parent) then return end
            if not Settings.ZombieESP then
                highlight.Enabled = false
                return
            end

            highlight.Enabled = true
            local awake = isZombieAwake(zombie)
            if awake ~= lastAwake then
                lastAwake = awake
                local col = awake and Settings.ZombieAwakeColor or Settings.ZombieDormantColor
                highlight.OutlineColor = col
                highlight.FillColor = col
                highlight.FillTransparency = awake and 0.65 or 0.8
            end
        end

        data.Update = updateZombieState

        if hum then
            local c1 = hum:GetPropertyChangedSignal("Health"):Connect(updateZombieState)
            local c2 = hum:GetPropertyChangedSignal("Sit"):Connect(updateZombieState)
            local c3 = hum:GetPropertyChangedSignal("PlatformStand"):Connect(updateZombieState)
            local c4 = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(updateZombieState)
            local c5 = hum.StateChanged:Connect(function() updateZombieState() end)

            table.insert(Connections, c1)
            table.insert(Connections, c2)
            table.insert(Connections, c3)
            table.insert(Connections, c4)
            table.insert(Connections, c5)
            table.insert(data.Conns, c1)
            table.insert(data.Conns, c2)
            table.insert(data.Conns, c3)
            table.insert(data.Conns, c4)
            table.insert(data.Conns, c5)
        end

        local cAttr = zombie.AttributeChanged:Connect(updateZombieState)
        local cChildAdd = zombie.ChildAdded:Connect(updateZombieState)
        local cChildRem = zombie.ChildRemoved:Connect(updateZombieState)
        local cAnc = zombie.AncestryChanged:Connect(function(_, parent)
            if not parent then removeZombieESP(zombie) end
        end)

        table.insert(Connections, cAttr)
        table.insert(Connections, cChildAdd)
        table.insert(Connections, cChildRem)
        table.insert(Connections, cAnc)
        table.insert(data.Conns, cAttr)
        table.insert(data.Conns, cChildAdd)
        table.insert(data.Conns, cChildRem)
        table.insert(data.Conns, cAnc)

        updateZombieState()
    end)
end

-- Player ESP
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

        ObjectsToDestroy[highlight] = true
        ObjectsToDestroy[nameBillboard] = true

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
        table.insert(Connections, hpConn)

        local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            killerCache[player] = nil
            cachedKingScourge = nil
            updateColor()
            updateKillerLabel()
            nameLabel.Text = player.Name
            if isKiller(player) then
                nameLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
            else
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end)
        table.insert(data.Conns, teamConn)
        table.insert(Connections, teamConn)

        local charAncestry = character.AncestryChanged:Connect(function(_, parent)
            if not parent then removePlayerESP(player) end
        end)
        table.insert(data.Conns, charAncestry)
        table.insert(Connections, charAncestry)
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end
    local cAdd = player.CharacterAdded:Connect(onCharacterAdded)
    table.insert(Connections, cAdd)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end
local pAdd = Players.PlayerAdded:Connect(function(player)
    setupPlayer(player)
    updateKillerLabel()
end)
local pRem = Players.PlayerRemoving:Connect(function(player)
    removePlayerESP(player)
    killerCache[player] = nil
    cachedKingScourge = nil
    updateKillerLabel()
end)
table.insert(Connections, pAdd)
table.insert(Connections, pRem)

-- Generator ESP
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

local function setupGenerator(generator)
    if not generator:IsA("Model") then return end
    if not (generator.Name == "Generator" or generator.Name:lower():find("generator")) then return end
    if activeGenerators[generator] then return end

    for _, ch in ipairs(generator:GetChildren()) do
        if ch:IsA("Highlight") and ch.Name == "ESPHighlight" then
            ch:Destroy()
        end
    end

    local targetPart = generator.PrimaryPart 
        or generator:FindFirstChild("RootPart") 
        or generator:FindFirstChild("HitBox") 
        or generator:FindFirstChildWhichIsA("BasePart")

    if not targetPart then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.OutlineColor = Settings.GenNormalColor
    highlight.FillColor = Settings.GenNormalColor
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
    label.TextColor3 = Settings.GenNormalColor
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 14
    label.RichText = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = bb

    ObjectsToDestroy[highlight] = true
    ObjectsToDestroy[bb] = true

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
            local isDone = (pct >= 100) or generator:GetAttribute("Completed") == true or generator:GetAttribute("isDone") == true

            highlight.Enabled = Settings.GenESP and Settings.GenHighlightEnabled

            if isDone then
                bb.Enabled = false
                label.Text = ""
                highlight.OutlineColor = Settings.GenCompleteColor
                highlight.FillColor = Settings.GenCompleteColor
                highlight.FillTransparency = 0.4
            else
                local kickCount = generator:GetAttribute("kickcount") or generator:GetAttribute("KickCount") or 0
                local activeColor = cachedPerkEquipped and Settings.GenPerkColor or Settings.GenNormalColor

                bb.Enabled = Settings.GenESP and Settings.GenBillboardEnabled
                label.Text = pct .. "% <font size=\"10\">[K: " .. kickCount .. "]</font>"
                label.TextColor3 = activeColor
                highlight.OutlineColor = activeColor
                highlight.FillColor = activeColor
                highlight.FillTransparency = 0.75
            end

            if isDone then
                for _, lData in pairs(activeLevers) do
                    if lData.Update then lData.Update() end
                end
            end
        end
    end

    data.Update = updateProgress

    local conn = generator.AttributeChanged:Connect(updateProgress)
    table.insert(data.Conns, conn)
    table.insert(Connections, conn)

    local ancConn = generator.AncestryChanged:Connect(function(_, parent)
        if not parent then removeGeneratorESP(generator) end
    end)
    table.insert(data.Conns, ancConn)
    table.insert(Connections, ancConn)

    updateProgress()
end

-- Exit Lever ESP
local function removeLeverESP(lever)
    if activeLevers[lever] then
        local data = activeLevers[lever]
        if data.Highlight and data.Highlight.Parent then data.Highlight:Destroy() end
        if data.Billboard and data.Billboard.Parent then data.Billboard:Destroy() end
        if data.Conns then
            for _, conn in ipairs(data.Conns) do conn:Disconnect() end
        end
        activeLevers[lever] = nil
    end
end

local function setupExitLever(lever)
    if not lever:IsA("Model") then return end
    local n = lever.Name:lower()
    if not (n == "exitlever" or n:find("lever")) then return end
    if activeLevers[lever] then return end

    for _, ch in ipairs(lever:GetChildren()) do
        if ch:IsA("Highlight") and ch.Name == "ExitGateHighlight" then
            ch:Destroy()
        end
    end

    local targetPart = lever:FindFirstChild("Main") 
        or lever:FindFirstChild("Lever") 
        or lever.PrimaryPart 
        or lever:FindFirstChildWhichIsA("BasePart")
    
    if not targetPart then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ExitGateHighlight"
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.OutlineColor = Settings.ExitLeverColor
    highlight.FillColor = Settings.ExitLeverColor
    highlight.Adornee = lever
    highlight.Enabled = false
    highlight.Parent = lever

    local _, size = lever:GetBoundingBox()
    local topOffset = (size.Y / 2) + 0.6

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPExitBillboard"
    bb.Size = UDim2.new(0, 80, 0, 26)
    bb.StudsOffset = Vector3.new(0, topOffset, 0)
    bb.AlwaysOnTop = true
    bb.Enabled = false
    bb.Parent = targetPart

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Settings.ExitLeverColor
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 14
    label.RichText = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = bb

    ObjectsToDestroy[highlight] = true
    ObjectsToDestroy[bb] = true

    local data = {
        Lever = lever,
        Highlight = highlight,
        Billboard = bb,
        Label = label,
        Progress = 0,
        IsPulling = false,
        LastPullTick = 0,
        Conns = {}
    }
    activeLevers[lever] = data

    local function updateLeverDisplay()
        if not (lever and lever.Parent) then return end
        local isPowered = areGatesPowered()

        if isPowered and Settings.ExitLeverESP then
            highlight.Enabled = true
            bb.Enabled = true

            local displayPct = math.floor(math.clamp(data.Progress or 0, 0, 100))
            label.Text = displayPct .. "%"

            if displayPct >= 100 then
                highlight.FillTransparency = 0.4
            else
                highlight.FillTransparency = 0.75
            end
        else
            highlight.Enabled = false
            bb.Enabled = false
        end
    end

    data.Update = updateLeverDisplay

    local ancConn = lever.AncestryChanged:Connect(function(_, parent)
        if not parent then removeLeverESP(lever) end
    end)
    table.insert(data.Conns, ancConn)
    table.insert(Connections, ancConn)

    updateLeverDisplay()
end

if leverAnimRemote then
    local cLAnim = leverAnimRemote.OnClientEvent:Connect(function(isPulling, leverPos)
        local targetPos = nil
        if typeof(leverPos) == "Vector3" then
            targetPos = leverPos
        elseif typeof(leverPos) == "CFrame" then
            targetPos = leverPos.Position
        elseif typeof(leverPos) == "Instance" then
            targetPos = leverPos:GetPivot().Position
        end

        for lever, data in pairs(activeLevers) do
            if lever and lever.Parent and targetPos then
                local pivot = lever:GetPivot().Position
                if (pivot - targetPos).Magnitude < 15 then
                    data.IsPulling = (isPulling == true)
                    data.LastPullTick = os.clock()
                end
            end
        end
    end)
    table.insert(Connections, cLAnim)
end

local cRenderStepped = RunService.RenderStepped:Connect(function(dt)
    local char = localPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")

    local pGui = localPlayer:FindFirstChild("PlayerGui") or PlayerGui
    local prog = pGui and pGui:FindFirstChild("ProgressPromptGui")
    local frame = prog and prog:FindFirstChild("Frame")
    local isBarActive = frame and frame.Visible
    local isExitBar = false

    if isBarActive then
        local textLabel = frame:FindFirstChild("TextLabel")
        if textLabel and textLabel.Text:upper():find("OPEN") then
            isExitBar = true
        end
    end

    local isExitingAttr = char and (char:GetAttribute("isExiting") == true or char:GetAttribute("overridelookscript") == true)
    local activeLocalLever = nil

    if (isExitBar or isExitingAttr) and myRoot then
        local closestDist = 15
        for lever, data in pairs(activeLevers) do
            if lever and lever.Parent then
                local dist = (lever:GetPivot().Position - myRoot.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    activeLocalLever = data
                end
            end
        end

        if activeLocalLever then
            local usedGradient = false
            if isBarActive then
                local bar = frame:FindFirstChild("Bar")
                local grad = bar and bar:FindFirstChild("UIGradient")
                if grad and grad.Offset.X < -0.105 and grad.Offset.X >= -0.975 then
                    local curX = grad.Offset.X
                    local emptyX = -0.971
                    local fullX = -0.105
                    local pct = math.clamp(((curX - emptyX) / (fullX - emptyX)) * 100, 0, 100)
                    activeLocalLever.Progress = pct
                    usedGradient = true
                end
            end

            if not usedGradient then
                activeLocalLever.Progress = math.min(100, (activeLocalLever.Progress or 0) + (dt / 20) * 100)
            end

            if activeLocalLever.Update then
                activeLocalLever.Update()
            end
        end
    end

    local now = os.clock()
    for _, data in pairs(activeLevers) do
        if data ~= activeLocalLever and data.IsPulling and (now - (data.LastPullTick or 0) < 0.8) then
            data.Progress = math.min(100, (data.Progress or 0) + (dt / 20) * 100)
            if data.Update then
                data.Update()
            end
        end
    end
end)
table.insert(Connections, cRenderStepped)

-- Workspace Watcher
local function scanModel(item)
    if not item:IsA("Model") then return end
    local n = item.Name:lower()
    if n == "generator" or n:find("generator") then
        setupGenerator(item)
    elseif isZombieCandidate(item) then
        setupZombie(item)
    elseif n == "exitlever" or (n:find("lever") and item.Parent and item.Parent.Name:lower():find("gate")) then
        setupExitLever(item)
    end
end

local function scanAllWorkspace()
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("Model") then
            scanModel(item)
        end
    end
end

scanAllWorkspace()

local descConn = Workspace.DescendantAdded:Connect(function(item)
    if item:IsA("Model") then
        task.defer(scanModel, item)
    end
end)
table.insert(Connections, descConn)

local descRemConn = Workspace.DescendantRemoving:Connect(function(item)
    if activeGenerators[item] then removeGeneratorESP(item) end
    if activeZombies[item] then removeZombieESP(item) end
    if activeLevers[item] then removeLeverESP(item) end
end)
table.insert(Connections, descRemConn)

updatePerkState()

local function hookSurvivorPerksGui()
    local survPerksGui = PlayerGui:FindFirstChild("SurvivorPerks")
    if survPerksGui then
        local p1 = survPerksGui.DescendantAdded:Connect(updatePerkState)
        local p2 = survPerksGui.DescendantRemoving:Connect(updatePerkState)
        table.insert(Connections, p1)
        table.insert(Connections, p2)
    end
end
hookSurvivorPerksGui()

local cCharAdded = localPlayer.CharacterAdded:Connect(function(char)
    cachedKingScourge = nil
    gatesPoweredFlag = false
    table.clear(killerCache)
    task.wait(1)
    updatePerkState()
    hookSurvivorPerksGui()
    scanAllWorkspace()
    updateKillerLabel()

    local pGui = localPlayer:FindFirstChild("PlayerGui") or PlayerGui
    if pGui then
        local prompt = pGui:FindFirstChild("SkillCheckPromptGui")
        if prompt then setupSkillCheckGui(prompt) end
    end
end)
table.insert(Connections, cCharAdded)

local perkLoop = task.spawn(function()
    while true do
        task.wait(0.5)
        for _, data in pairs(activeZombies) do
            if data.Update then
                data.Update()
            end
        end
        local isEquipped = checkPerkEquipped()
        if isEquipped ~= cachedPerkEquipped then
            updatePerkState()
        end
        updateKillerLabel()
        if Settings.AlwaysPerfectionistBoost and cachedPerkEquipped then
            local char = localPlayer.Character
            if char and (char:GetAttribute("repairing") or char:FindFirstChild("RepairAnim")) then
                forcePerfectionistBoost()
            end
        end
    end
end)
table.insert(Threads, perkLoop)

local existingPrompt = PlayerGui:FindFirstChild("SkillCheckPromptGui")
if existingPrompt then setupSkillCheckGui(existingPrompt) end

local cGuiAdd = PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "SkillCheckPromptGui" or child.Name:lower():find("skillcheck") then
        setupSkillCheckGui(child)
    end
end)
table.insert(Connections, cGuiAdd)
