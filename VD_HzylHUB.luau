-- Made by hzyl
local getHui = gethui or function() return game:GetService("CoreGui") end
local parentContainer = getHui()

if parentContainer:FindFirstChild("hzyl_GUI") then
    parentContainer:FindFirstChild("hzyl_GUI"):Destroy()
end

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

-- Balanced Soft Fullbright Manager
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

-- Efficient Trackers & Cleanups
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
    for player, data in pairs(activePlayers) do
        if data.Highlight and data.Highlight.Parent then
            data.Highlight.Enabled = Settings.PlayerESP and Settings.PlayerHighlightEnabled
        end
        if data.Billboard and data.Billboard.Parent then
            data.Billboard.Enabled = Settings.PlayerESP and Settings.PlayerBillboardEnabled
        end
    end
end

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "hzyl_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentContainer

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 460)
MainFrame.Position = UDim2.new(0.05, 0, 0.18, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(40, 50, 70)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleBar

local AccentLine = Instance.new("Frame")
AccentLine.Size = UDim2.new(1, 0, 0, 2)
AccentLine.Position = UDim2.new(0, 0, 1, -2)
AccentLine.BackgroundColor3 = Color3.fromRGB(0, 180, 240)
AccentLine.BorderSizePixel = 0
AccentLine.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -50, 1, 0)
TitleText.Position = UDim2.new(0, 16, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "MADE BY HZYL"
TitleText.TextColor3 = Color3.fromRGB(240, 245, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBold
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TitleBar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent = CloseBtn

local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local FloatCircle = Instance.new("TextButton")
FloatCircle.Name = "FloatCircle"
FloatCircle.Size = UDim2.new(0, 48, 0, 48)
FloatCircle.Position = UDim2.new(0, 20, 0.5, -24)
FloatCircle.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
FloatCircle.Text = ""
FloatCircle.Parent = ScreenGui

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = FloatCircle

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Color = Color3.fromRGB(0, 180, 240)
CircleStroke.Thickness = 2
CircleStroke.Parent = FloatCircle

local BurgerContainer = Instance.new("Frame")
BurgerContainer.Size = UDim2.new(0, 22, 0, 16)
BurgerContainer.Position = UDim2.new(0.5, -11, 0.5, -8)
BurgerContainer.BackgroundTransparency = 1
BurgerContainer.Parent = FloatCircle

for i = 1, 3 do
    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, 0, 0, 3)
    Line.Position = UDim2.new(0, 0, 0, (i - 1) * 6.5)
    Line.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
    Line.BorderSizePixel = 0
    Line.Parent = BurgerContainer

    local LineCorner = Instance.new("UICorner")
    LineCorner.CornerRadius = UDim.new(1, 0)
    LineCorner.Parent = Line
end

local floatDragging, floatDragInput, floatDragStart, floatStartPos
FloatCircle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        floatDragging = true
        floatDragStart = input.Position
        floatStartPos = FloatCircle.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                floatDragging = false
            end
        end)
    end
end)
FloatCircle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        floatDragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == floatDragInput and floatDragging then
        local delta = input.Position - floatDragStart
        FloatCircle.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
    end
end)

local clickTime = 0
FloatCircle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        clickTime = tick()
    end
end)
FloatCircle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - clickTime < 0.25 then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -24, 0, 36)
TabBar.Position = UDim2.new(0, 12, 0, 52)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Padding = UDim.new(0, 4)
TabListLayout.Parent = TabBar

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -24, 1, -100)
ContentContainer.Position = UDim2.new(0, 12, 0, 94)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

local Pages = {}

local function CreateTab(name, order)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(0.31, 0, 1, -6)
    TabBtn.Position = UDim2.new(0, 0, 0, 3)
    TabBtn.BackgroundColor3 = (order == 1) and Color3.fromRGB(0, 180, 240) or Color3.fromRGB(24, 30, 42)
    TabBtn.Text = name
    TabBtn.TextColor3 = (order == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 170, 190)
    TabBtn.Font = Enum.Font.GothamBold
    TabBtn.TextSize = 12
    TabBtn.LayoutOrder = order
    TabBtn.Parent = TabBar

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 6)
    TabCorner.Parent = TabBtn

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 240)
    Page.Visible = (order == 1)
    Page.Parent = ContentContainer

    local PageLayout = Instance.new("UIListLayout")
    PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PageLayout.Padding = UDim.new(0, 8)
    PageLayout.Parent = Page

    Pages[name] = {Btn = TabBtn, Page = Page}

    TabBtn.MouseButton1Click:Connect(function()
        for tabName, tabData in pairs(Pages) do
            local active = (tabName == name)
            tabData.Page.Visible = active
            tabData.Btn.BackgroundColor3 = active and Color3.fromRGB(0, 180, 240) or Color3.fromRGB(24, 30, 42)
            tabData.Btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 170, 190)
        end
    end)

    return Page
end

local GenPage = CreateTab("GENERATORS", 1)
local PlayerPage = CreateTab("PLAYERS", 2)
local InfoPage = CreateTab("INFO", 3)

local function CreateToggle(parentPage, name, defaultState, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -6, 0, 44)
    Frame.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
    Frame.BorderSizePixel = 0
    Frame.Parent = parentPage

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.68, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 228, 245)
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 58, 0, 26)
    Btn.Position = UDim2.new(1, -68, 0.5, -13)
    Btn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 180, 240) or Color3.fromRGB(60, 68, 84)
    Btn.Text = defaultState and "ON" or "OFF"
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.Parent = Frame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 13)
    BtnCorner.Parent = Btn

    local state = defaultState
    Btn.MouseButton1Click:Connect(function()
        state = not state
        Btn.Text = state and "ON" or "OFF"
        Btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 240) or Color3.fromRGB(60, 68, 84)
        callback(state)
    end)
    return Btn
end

CreateToggle(GenPage, "Master Generator ESP", Settings.GenESP, function(v) 
    Settings.GenESP = v 
    updateAllGeneratorsESP()
end)
CreateToggle(GenPage, "Generator Highlights", Settings.GenHighlightEnabled, function(v) 
    Settings.GenHighlightEnabled = v 
    updateAllGeneratorsESP()
end)
CreateToggle(GenPage, "Generator Progress", Settings.GenBillboardEnabled, function(v) 
    Settings.GenBillboardEnabled = v 
    updateAllGeneratorsESP()
end)
CreateToggle(GenPage, "Auto SkillCheck", Settings.AutoSkillCheck, function(v) Settings.AutoSkillCheck = v end)
CreateToggle(GenPage, "Perfect Skillcheck (+1% Progress)", true, function(v) Settings.SkillCheckMode = v and "great" or "good" end)

local UnstickBtn = Instance.new("TextButton")
UnstickBtn.Size = UDim2.new(1, -6, 0, 38)
UnstickBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
UnstickBtn.Text = "UNSTICK CHARACTER"
UnstickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
UnstickBtn.Font = Enum.Font.GothamBold
UnstickBtn.TextSize = 13
UnstickBtn.Parent = GenPage

local UnstickCorner = Instance.new("UICorner")
UnstickCorner.CornerRadius = UDim.new(0, 8)
UnstickCorner.Parent = UnstickBtn

UnstickBtn.MouseButton1Click:Connect(function()
    forceUnstickCharacter()
end)

local StatusBox = Instance.new("Frame")
StatusBox.Size = UDim2.new(1, -6, 0, 44)
StatusBox.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
StatusBox.BorderSizePixel = 0
StatusBox.Parent = GenPage

local StatusBoxCorner = Instance.new("UICorner")
StatusBoxCorner.CornerRadius = UDim.new(0, 8)
StatusBoxCorner.Parent = StatusBox

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -20, 1, 0)
StatusText.Position = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "STATUS: Active"
StatusText.TextColor3 = Color3.fromRGB(0, 220, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.TextYAlignment = Enum.TextYAlignment.Center
StatusText.Parent = StatusBox

CreateToggle(PlayerPage, "Master Player ESP", Settings.PlayerESP, function(v) 
    Settings.PlayerESP = v 
    updateAllPlayersESP()
end)
CreateToggle(PlayerPage, "Player Highlights", Settings.PlayerHighlightEnabled, function(v) 
    Settings.PlayerHighlightEnabled = v 
    updateAllPlayersESP()
end)
CreateToggle(PlayerPage, "Player Names", Settings.PlayerBillboardEnabled, function(v) 
    Settings.PlayerBillboardEnabled = v 
    updateAllPlayersESP()
end)
CreateToggle(PlayerPage, "Soft Fullbright", Settings.Fullbright, function(v)
    Settings.Fullbright = v
    updateLighting()
end)

local PlayerStatusBox = Instance.new("Frame")
PlayerStatusBox.Size = UDim2.new(1, -6, 0, 44)
PlayerStatusBox.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
PlayerStatusBox.BorderSizePixel = 0
PlayerStatusBox.Parent = PlayerPage

local PlayerStatusCorner = Instance.new("UICorner")
PlayerStatusCorner.CornerRadius = UDim.new(0, 8)
PlayerStatusCorner.Parent = PlayerStatusBox

local PlayerStatusText = Instance.new("TextLabel")
PlayerStatusText.Size = UDim2.new(1, -20, 1, 0)
PlayerStatusText.Position = UDim2.new(0, 10, 0, 0)
PlayerStatusText.BackgroundTransparency = 1
PlayerStatusText.Text = "Killer: Bright Red Outline ([KILLER] Label)\nSurvivors: Green / Orange / Red (by HP)"
PlayerStatusText.TextColor3 = Color3.fromRGB(240, 245, 255)
PlayerStatusText.TextSize = 12
PlayerStatusText.Font = Enum.Font.GothamBold
PlayerStatusText.TextYAlignment = Enum.TextYAlignment.Center
PlayerStatusText.Parent = PlayerStatusBox

local function refreshPlayerInfoTab()
    for _, child in ipairs(InfoPage:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local InfoTitle = Instance.new("TextLabel")
    InfoTitle.Size = UDim2.new(1, -6, 0, 28)
    InfoTitle.BackgroundTransparency = 1
    InfoTitle.Text = "ACTIVE PLAYERS & LOADOUT"
    InfoTitle.TextColor3 = Color3.fromRGB(0, 180, 240)
    InfoTitle.TextSize = 15
    InfoTitle.Font = Enum.Font.GothamBold
    InfoTitle.TextXAlignment = Enum.TextXAlignment.Left
    InfoTitle.Parent = InfoPage

    for _, p in ipairs(Players:GetPlayers()) do
        local isKill = isKiller(p)
        local roleStr = isKill and "KILLER" or "SURVIVOR"
        local itemStr = p:GetAttribute("EquippedItem") or "None"
        
        if itemStr == "None" and p.Character then
            local tool = p.Character:FindFirstChildOfClass("Tool")
            if tool then
                itemStr = tool.Name
            end
        end

        local killerStr = p:GetAttribute("SelectedKiller") or (isKill and "King Scourge" or "Standard")
        local lvl = p:GetAttribute("Level") or 1

        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, -6, 0, 64)
        Card.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
        Card.BorderSizePixel = 0
        Card.Parent = InfoPage

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = Card

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Size = UDim2.new(1, -20, 0, 30)
        NameLabel.Position = UDim2.new(0, 12, 0, 5)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = p.Name .. " [" .. roleStr .. "]"
        NameLabel.TextColor3 = isKill and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(240, 245, 255)
        NameLabel.TextSize = 16
        NameLabel.Font = Enum.Font.GothamBold
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.Parent = Card

        local ItemLabel = Instance.new("TextLabel")
        ItemLabel.Size = UDim2.new(1, -20, 0, 24)
        ItemLabel.Position = UDim2.new(0, 12, 0, 33)
        ItemLabel.BackgroundTransparency = 1
        ItemLabel.Text = isKill and ("Killer: " .. tostring(killerStr) .. " | Level: " .. tostring(lvl)) or ("Item: " .. tostring(itemStr) .. " | Level: " .. tostring(lvl))
        ItemLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
        ItemLabel.TextSize = 14
        ItemLabel.Font = Enum.Font.GothamBold
        ItemLabel.TextXAlignment = Enum.TextXAlignment.Left
        ItemLabel.Parent = Card
    end

    local FooterBox = Instance.new("Frame")
    FooterBox.Size = UDim2.new(1, -6, 0, 42)
    FooterBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    FooterBox.BorderSizePixel = 0
    FooterBox.Parent = InfoPage

    local FooterCorner = Instance.new("UICorner")
    FooterCorner.CornerRadius = UDim.new(0, 8)
    FooterCorner.Parent = FooterBox

    local FooterStroke = Instance.new("UIStroke")
    FooterStroke.Color = Color3.fromRGB(0, 180, 240)
    FooterStroke.Thickness = 1.5
    FooterStroke.Parent = FooterBox

    local FooterText = Instance.new("TextLabel")
    FooterText.Size = UDim2.new(1, 0, 1, 0)
    FooterText.BackgroundTransparency = 1
    FooterText.Text = "vibecoded using Gemini"
    FooterText.TextColor3 = Color3.fromRGB(0, 220, 255)
    FooterText.TextSize = 14
    FooterText.Font = Enum.Font.GothamBold
    FooterText.TextXAlignment = Enum.TextXAlignment.Center
    FooterText.Parent = FooterBox
end

refreshPlayerInfoTab()
Players.PlayerAdded:Connect(refreshPlayerInfoTab)
Players.PlayerRemoving:Connect(refreshPlayerInfoTab)

-- Optimized Event-Driven Player ESP
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
