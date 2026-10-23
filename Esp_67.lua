--[[
    Brisk Survival Script — Enhanced v2
    Part 1/5: Services, Theme, Config, Utilities
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting       = game:GetService("Lighting")
local TweenService   = game:GetService("TweenService")
local LocalPlayer    = Players.LocalPlayer
local Camera         = workspace.CurrentCamera
local Drawing        = Drawing or nil

local Theme = {
    Background   = Color3.fromRGB(12, 12, 16),
    SideBar      = Color3.fromRGB(18, 18, 24),
    Element      = Color3.fromRGB(28, 28, 36),
    ElementHover = Color3.fromRGB(42, 42, 54),
    Accent       = Color3.fromRGB(0, 180, 255),
    AccentGreen  = Color3.fromRGB(0, 220, 120),
    AccentRed    = Color3.fromRGB(255, 60, 60),
    AccentOff    = Color3.fromRGB(55, 55, 68),
    Text         = Color3.fromRGB(240, 240, 245),
    TextDim      = Color3.fromRGB(130, 130, 145),
    Border       = Color3.fromRGB(0, 180, 255),
}

local Config = {
    ESP = true, Box = true, Tracer = true, Chams = true,
    Name = true, Distance = true, Health = true,
    MaxDist = 1000, Color = Color3.fromRGB(255, 50, 50),
    TracerOrigin = "Bottom", ItemESP = true,
    SilentAim = false, ShowFOV = true, FOV = 150,
    Aimbot = false, AimbotPart = "Head", AimbotSmooth = 0.15,
    Fullbright = true, NoFog = true, NoWeather = true,
}

local oldGui = game.CoreGui:FindFirstChild("BriskSurvivalScript")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BriskSurvivalScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game.CoreGui

local fovCircle
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness    = 1.5
    fovCircle.Color        = Theme.Accent
    fovCircle.Filled       = false
    fovCircle.Transparency = 0.75
    fovCircle.Visible      = false
end

local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function lerp(a, b, t) return a + (b - a) * t end
-- Part 2/5: Environment, Target Finder, Silent Aim, Aimbot

local function applyEnvironment()
    if Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2; Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(0,0,0)
        Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)
        Lighting.Brightness = 1; Lighting.GlobalShadows = true
    end
    if Config.NoFog then Lighting.FogEnd = 1e6; Lighting.FogStart = 0
    else Lighting.FogEnd = 1000; Lighting.FogStart = 0 end
    if Config.NoWeather then
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        local cld = Lighting:FindFirstChildOfClass("Clouds")
        if atm then atm:Destroy() end
        if cld then cld:Destroy() end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") then
                local n = obj.Name:lower()
                if n:find("rain") or n:find("snow") or n:find("weather") or n:find("storm") then
                    obj.Enabled = false
                end
            end
        end
    end
end
task.spawn(function() while task.wait(1) do pcall(applyEnvironment) end end)

local function getClosestTarget(fovRadius)
    local closest, shortestDist = nil, math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local part = player.Character:FindFirstChild(Config.AimbotPart)
                      or player.Character:FindFirstChild("Head")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist <= fovRadius and dist < shortestDist then
                        shortestDist = dist; closest = player
                    end
                end
            end
        end
    end
    return closest
end

local oldNamecall
local safeHook = pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller() and Config.SilentAim
        and (method == "FireServer" or method == "InvokeServer") then
            local remoteName = self.Name:lower()
            if remoteName:find("fire") or remoteName:find("shoot")
            or remoteName:find("hit") or remoteName:find("attack")
            or remoteName:find("weapon") or remoteName:find("damage") then
                local target = getClosestTarget(Config.FOV)
                if target and target.Character then
                    local targetPart = target.Character:FindFirstChild("Head")
                                    or target.Character:FindFirstChild("HumanoidRootPart")
                    if targetPart then
                        if typeof(args[1]) == "Vector3" then args[1] = targetPart.Position
                        elseif typeof(args[1]) == "CFrame" then
                            args[1] = CFrame.lookAt(args[1].Position, targetPart.Position)
                        end
                        if typeof(args[2]) == "Vector3" and typeof(args[1]) == "Vector3" then
                            args[2] = (targetPart.Position - args[1]).Unit
                        end
                    end
                end
            end
        end
        return oldNamecall(self, table.unpack(args))
    end)
end)
if not safeHook then
    warn("[BSS] hookmetamethod tidak tersedia — Silent Aim dinonaktifkan")
    Config.SilentAim = false
end

RunService.RenderStepped:Connect(function()
    if not Config.Aimbot then return end
    local target = getClosestTarget(Config.FOV)
    if not target or not target.Character then return end
    local part = target.Character:FindFirstChild(Config.AimbotPart)
              or target.Character:FindFirstChild("Head")
    if not part then return end
    local targetCF = CFrame.lookAt(Camera.CFrame.Position, part.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.AimbotSmooth)
end)
-- Part 3/5: ESP Objects, Item ESP

local espObjects = {}
local itemEspObjects = {}

local function destroyESPData(data)
    if not data then return end
    for _, obj in pairs(data) do
        pcall(function()
            if typeof(obj) == "Instance" then obj:Destroy()
            elseif typeof(obj) == "table" and obj.Remove then obj:Remove() end
        end)
    end
end

local function createESP(player)
    if player == LocalPlayer then return end
    local function setup(character)
        if not character then return end
        character:WaitForChild("HumanoidRootPart", 5)
        character:WaitForChild("Head", 5)
        if not character:FindFirstChild("HumanoidRootPart")
        or not character:FindFirstChild("Head") then return end
        if espObjects[player] then destroyESPData(espObjects[player]) end
        local data = {}

        local highlight = Instance.new("Highlight")
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.45; highlight.OutlineTransparency = 0
        highlight.FillColor = Config.Color; highlight.OutlineColor = Config.Color
        highlight.Enabled = Config.Chams; highlight.Parent = character
        data.highlight = highlight

        local billboard = Instance.new("BillboardGui")
        billboard.Adornee = character.Head; billboard.Size = UDim2.new(0, 220, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3, 0); billboard.AlwaysOnTop = true
        billboard.Enabled = (Config.Name or Config.Distance or Config.Health)
        billboard.Parent = character.Head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1,0,0,18); nameLabel.Position = UDim2.new(0,0,0,0)
        nameLabel.BackgroundTransparency = 1; nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextColor3 = Config.Color; nameLabel.TextStrokeTransparency = 0.4
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        nameLabel.TextSize = 13; nameLabel.Text = player.Name; nameLabel.Parent = billboard

        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1,0,0,14); distLabel.Position = UDim2.new(0,0,0,20)
        distLabel.BackgroundTransparency = 1; distLabel.Font = Enum.Font.Gotham
        distLabel.TextColor3 = Theme.Text; distLabel.TextStrokeTransparency = 0.5
        distLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        distLabel.TextSize = 11; distLabel.Text = ""; distLabel.Parent = billboard

        local hpLabel = Instance.new("TextLabel")
        hpLabel.Size = UDim2.new(1,0,0,14); hpLabel.Position = UDim2.new(0,0,0,36)
        hpLabel.BackgroundTransparency = 1; hpLabel.Font = Enum.Font.Gotham
        hpLabel.TextColor3 = Theme.AccentGreen; hpLabel.TextStrokeTransparency = 0.5
        hpLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        hpLabel.TextSize = 11; hpLabel.Text = ""; hpLabel.Parent = billboard

        data.billboard = billboard; data.nameLabel = nameLabel
        data.distLabel = distLabel; data.hpLabel = hpLabel

        if Drawing then
            local box = Drawing.new("Square")
            box.Visible = false; box.Color = Config.Color; box.Thickness = 1.5; box.Filled = false
            data.box = box
            local tracer = Drawing.new("Line")
            tracer.Visible = false; tracer.Color = Config.Color; tracer.Thickness = 1.5
            data.tracer = tracer
        end
        espObjects[player] = data
    end
    player.CharacterAdded:Connect(setup)
    if player.Character then task.spawn(setup, player.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then destroyESPData(espObjects[player]); espObjects[player] = nil end
end)

local LootKeywords = {"loot","drop","item","crate","bag","weapon","gun","ammo","med","scrap","box","chest","supply","resource","food","tool"}
local function isLoot(obj)
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end
    local name = obj.Name:lower()
    for _, kw in ipairs(LootKeywords) do if name:find(kw) then return true end end
    return false
end

local lastItemScan = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastItemScan < 0.5 then return end
    lastItemScan = now
    for obj, data in pairs(itemEspObjects) do
        if not obj.Parent then
            pcall(function() data.highlight:Destroy() end)
            pcall(function() data.billboard:Destroy() end)
            itemEspObjects[obj] = nil
        end
    end
    if not Config.ItemESP then
        for obj, data in pairs(itemEspObjects) do
            pcall(function() data.highlight:Destroy() end)
            pcall(function() data.billboard:Destroy() end)
            itemEspObjects[obj] = nil
        end
        return
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if isLoot(obj) and not itemEspObjects[obj] then
            local isChar = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == obj then isChar = true; break end
            end
            if not isChar then
                local hl = Instance.new("Highlight")
                hl.Adornee = obj; hl.FillColor = Color3.fromRGB(255,215,0)
                hl.OutlineColor = Color3.fromRGB(255,255,255)
                hl.FillTransparency = 0.4
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = obj
                local bb = Instance.new("BillboardGui")
                bb.Adornee = obj; bb.Size = UDim2.new(0,120,0,30); bb.AlwaysOnTop = true; bb.Parent = obj
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
                lbl.TextColor3 = Color3.fromRGB(255,215,0); lbl.TextStrokeTransparency = 0.4
                lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
                lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.Text = obj.Name; lbl.Parent = bb
                itemEspObjects[obj] = {highlight = hl, billboard = bb}
            end
        end
    end
end)
-- Part 4/5: ESP Render Loop + GUI Builder

RunService.RenderStepped:Connect(function()
    if fovCircle then
        local showFov = (Config.SilentAim or Config.Aimbot) and Config.ShowFOV
        fovCircle.Visible = showFov
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        fovCircle.Radius = Config.FOV
    end
    for player, data in pairs(espObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if hrp and head and myHRP then
            local dist = (myHRP.Position - hrp.Position).Magnitude
            local inRange = Config.ESP and dist <= Config.MaxDist
            local hp = hum and hum.Health or 0
            local maxHp = hum and hum.MaxHealth or 100
            if data.highlight then
                data.highlight.Enabled = inRange and Config.Chams
                data.highlight.FillColor = Config.Color; data.highlight.OutlineColor = Config.Color
            end
            if data.billboard then
                local show = inRange and (Config.Name or Config.Distance or Config.Health)
                data.billboard.Enabled = show
                if show then
                    if data.nameLabel then
                        data.nameLabel.Visible = Config.Name
                        data.nameLabel.TextColor3 = Config.Color; data.nameLabel.Text = player.Name
                    end
                    if data.distLabel then
                        data.distLabel.Visible = Config.Distance
                        data.distLabel.Text = string.format("[%.0fm]", dist)
                    end
                    if data.hpLabel then
                        data.hpLabel.Visible = Config.Health
                        local pct = math.clamp(hp / math.max(maxHp,1), 0, 1)
                        local r = math.floor(255*(1-pct)); local g = math.floor(255*pct)
                        data.hpLabel.TextColor3 = Color3.fromRGB(r,g,50)
                        data.hpLabel.Text = string.format("HP: %.0f / %.0f", hp, maxHp)
                    end
                end
            end
            if data.box and data.tracer and Drawing then
                if inRange and (Config.Box or Config.Tracer) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local headScreen = Camera:WorldToViewportPoint(head.Position)
                        local height = math.abs(headScreen.Y - screenPos.Y) * 2.2
                        local width = height * 0.55
                        data.box.Visible = Config.Box; data.box.Size = Vector2.new(width, height)
                        data.box.Position = Vector2.new(screenPos.X - width/2, screenPos.Y - height/2)
                        data.box.Color = Config.Color
                        data.tracer.Visible = Config.Tracer; data.tracer.Color = Config.Color
                        local origin = Config.TracerOrigin == "Mouse"
                            and UserInputService:GetMouseLocation()
                            or Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                        data.tracer.From = origin; data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    else data.box.Visible = false; data.tracer.Visible = false end
                else data.box.Visible = false; data.tracer.Visible = false end
            end
        else
            if data.highlight then data.highlight.Enabled = false end
            if data.billboard then data.billboard.Enabled = false end
            if data.box then data.box.Visible = false end
            if data.tracer then data.tracer.Visible = false end
        end
    end
end)

local function CreateToggle(parent, text, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,34); btn.BackgroundColor3 = Theme.Element
    btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-54,1,0); lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = btn
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0,32,0,17); pill.Position = UDim2.new(1,-42,0.5,-8.5)
    pill.BackgroundColor3 = default and Theme.Accent or Theme.AccentOff; pill.Parent = btn
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,13,0,13)
    circle.Position = default and UDim2.new(1,-15,0.5,-6.5) or UDim2.new(0,2,0.5,-6.5)
    circle.BackgroundColor3 = Color3.fromRGB(255,255,255); circle.Parent = pill
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
    local state = default
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Element}):Play() end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill,TweenInfo.new(0.2),{BackgroundColor3=state and Theme.Accent or Theme.AccentOff}):Play()
        TweenService:Create(circle,TweenInfo.new(0.2),{Position=state and UDim2.new(1,-15,0.5,-6.5) or UDim2.new(0,2,0.5,-6.5)}):Play()
        callback(state)
    end)
end

local function CreateSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,50); frame.BackgroundColor3 = Theme.Element
    frame.BorderSizePixel = 0; frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-20,0,20); lbl.Position = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1; lbl.Text = text..": "..tostring(default)
    lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = frame
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-20,0,6); track.Position = UDim2.new(0,10,0,32)
    track.BackgroundColor3 = Theme.AccentOff; track.BorderSizePixel = 0; track.Parent = frame
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Theme.Accent; fill.BorderSizePixel = 0; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local dragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
            local val = math.floor(lerp(min, max, rel))
            fill.Size = UDim2.new(rel,0,1,0); lbl.Text = text..": "..tostring(val); callback(val)
        end
    end)
end

local function CreateColorPicker(parent, text, callback)
    local colors = {Color3.fromRGB(255,50,50),Color3.fromRGB(50,255,50),Color3.fromRGB(50,50,255),Color3.fromRGB(255,255,50),Color3.fromRGB(255,50,255),Color3.fromRGB(0,180,255),Color3.fromRGB(255,255,255)}
    local idx = 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,34); btn.BackgroundColor3 = Theme.Element
    btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-50,1,0); lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = btn
    local colorBox = Instance.new("Frame")
    colorBox.Size = UDim2.new(0,20,0,20); colorBox.Position = UDim2.new(1,-30,0.5,-10)
    colorBox.BackgroundColor3 = Config.Color; colorBox.Parent = btn
    Instance.new("UICorner", colorBox).CornerRadius = UDim.new(0,5)
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Element}):Play() end)
    btn.MouseButton1Click:Connect(function()
        idx = (idx % #colors) + 1; local c = colors[idx]
        colorBox.BackgroundColor3 = c; Config.Color = c
        for _, data in pairs(espObjects) do
            if data.highlight then data.highlight.FillColor = c; data.highlight.OutlineColor = c end
            if data.nameLabel then data.nameLabel.TextColor3 = c end
            if data.box then data.box.Color = c end
            if data.tracer then data.tracer.Color = c end
        end
        callback(c)
    end)
end
-- Part 5/5: Main Window, Tabs, Keybinds

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,460,0,270); Main.Position = UDim2.new(0.5,-230,0.5,-135)
Main.BackgroundColor3 = Theme.Background; Main.BorderSizePixel = 0; Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,10)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Theme.Border; mainStroke.Thickness = 1.5; mainStroke.Transparency = 0.25
MakeDraggable(Main)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1,0,0,36); TopBar.BackgroundColor3 = Theme.SideBar
TopBar.BorderSizePixel = 0; TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0,10)
local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1,0,0,10); topFix.Position = UDim2.new(0,0,1,-10)
topFix.BackgroundColor3 = Theme.SideBar; topFix.BorderSizePixel = 0; topFix.Parent = TopBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1,-80,1,0); TitleText.Position = UDim2.new(0,14,0,0)
TitleText.BackgroundTransparency = 1; TitleText.Text = "⚡ Brisk Survival Script"
TitleText.TextColor3 = Theme.Text; TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13; TitleText.TextXAlignment = Enum.TextXAlignment.Left; TitleText.Parent = TopBar

local SubText = Instance.new("TextLabel")
SubText.Size = UDim2.new(0,120,1,0); SubText.Position = UDim2.new(1,-155,0,0)
SubText.BackgroundTransparency = 1; SubText.Text = "RightShift = Toggle"
SubText.TextColor3 = Theme.TextDim; SubText.Font = Enum.Font.Gotham
SubText.TextSize = 10; SubText.TextXAlignment = Enum.TextXAlignment.Left; SubText.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,24,0,24); CloseBtn.Position = UDim2.new(1,-30,0.5,-12)
CloseBtn.BackgroundColor3 = Theme.AccentRed; CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Theme.Text; CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11; CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,6)

local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0,110,1,-36); SideBar.Position = UDim2.new(0,0,0,36)
SideBar.BackgroundColor3 = Theme.SideBar; SideBar.BorderSizePixel = 0; SideBar.Parent = Main
local sideFix = Instance.new("Frame")
sideFix.Size = UDim2.new(0,10,1,0); sideFix.Position = UDim2.new(1,-10,0,0)
sideFix.BackgroundColor3 = Theme.SideBar; sideFix.BorderSizePixel = 0; sideFix.Parent = SideBar
local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0,5); SideLayout.SortOrder = Enum.SortOrder.LayoutOrder; SideLayout.Parent = SideBar
local SidePadding = Instance.new("UIPadding")
SidePadding.PaddingTop = UDim.new(0,10); SidePadding.PaddingLeft = UDim.new(0,8)
SidePadding.PaddingRight = UDim.new(0,8); SidePadding.Parent = SideBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1,-110,1,-36); ContentArea.Position = UDim2.new(0,110,0,36)
ContentArea.BackgroundTransparency = 1; ContentArea.Parent = Main

local Pages = {}
local function SetActiveTab(name)
    for n, obj in pairs(Pages) do
        if n == name then
            obj.Page.Visible = true
            TweenService:Create(obj.Btn,TweenInfo.new(0.18),{BackgroundColor3=Theme.Accent,TextColor3=Theme.Text}):Play()
        else
            obj.Page.Visible = false
            TweenService:Create(obj.Btn,TweenInfo.new(0.18),{BackgroundColor3=Theme.Element,TextColor3=Theme.TextDim}):Play()
        end
    end
end

local function CreateTab(name, isDefault)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,30)
    btn.BackgroundColor3 = isDefault and Theme.Accent or Theme.Element
    btn.Text = name; btn.TextColor3 = isDefault and Theme.Text or Theme.TextDim
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12; btn.Parent = SideBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1,-20,1,-10); page.Position = UDim2.new(0,10,0,5)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Theme.Accent
    page.CanvasSize = UDim2.new(0,0,0,0); page.Visible = isDefault or false; page.Parent = ContentArea
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0,6); layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+12)
    end)
    Pages[name] = {Btn=btn, Page=page, Layout=layout}
    btn.MouseButton1Click:Connect(function() SetActiveTab(name) end)
end

CreateTab("Combat", true); CreateTab("Visuals", false); CreateTab("Misc", false)

CreateToggle(Pages["Combat"].Page, "🎯 Aimbot (P = Toggle)", Config.Aimbot, function(v) Config.Aimbot = v end)
CreateSlider(Pages["Combat"].Page, "Aim Smooth", 1, 20, math.floor(Config.AimbotSmooth*100), function(v) Config.AimbotSmooth = v/100 end)
CreateToggle(Pages["Combat"].Page, "🔇 Silent Aim", Config.SilentAim, function(v) Config.SilentAim = v end)
CreateToggle(Pages["Combat"].Page, "Show FOV Circle", Config.ShowFOV, function(v) Config.ShowFOV = v end)
CreateSlider(Pages["Combat"].Page, "FOV Size (px)", 50, 500, Config.FOV, function(v) Config.FOV = v end)

CreateToggle(Pages["Visuals"].Page, "Master ESP", Config.ESP, function(v) Config.ESP = v end)
CreateToggle(Pages["Visuals"].Page, "Box ESP", Config.Box, function(v) Config.Box = v end)
CreateToggle(Pages["Visuals"].Page, "Tracer ESP", Config.Tracer, function(v) Config.Tracer = v end)
CreateToggle(Pages["Visuals"].Page, "Chams (Highlight)", Config.Chams, function(v) Config.Chams = v end)
CreateToggle(Pages["Visuals"].Page, "Name & Distance", Config.Name, function(v) Config.Name=v; Config.Distance=v end)
CreateToggle(Pages["Visuals"].Page, "Health Bar", Config.Health, function(v) Config.Health = v end)
CreateToggle(Pages["Visuals"].Page, "Item / Loot ESP", Config.ItemESP, function(v) Config.ItemESP = v end)
CreateColorPicker(Pages["Visuals"].Page, "Player ESP Color (tap to cycle)", function(_) end)
CreateTextBox(Pages["Visuals"].Page, "Max Distance (studs)", Config.MaxDist, function(v) Config.MaxDist = v end)

CreateToggle(Pages["Misc"].Page, "☀️ Fullbright", Config.Fullbright, function(v) Config.Fullbright = v end)
CreateToggle(Pages["Misc"].Page, "🌫️ No Fog", Config.NoFog, function(v) Config.NoFog = v end)
CreateToggle(Pages["Misc"].Page, "🌧️ No Weather", Config.NoWeather, function(v) Config.NoWeather = v end)

local MobileBtn = Instance.new("TextButton")
MobileBtn.Size = UDim2.new(0,54,0,54); MobileBtn.Position = UDim2.new(0,16,0.5,-27)
MobileBtn.BackgroundColor3 = Theme.SideBar; MobileBtn.Text = "BSS"
MobileBtn.TextColor3 = Theme.Accent; MobileBtn.Font = Enum.Font.GothamBlack
MobileBtn.TextSize = 14; MobileBtn.Visible = false; MobileBtn.ZIndex = 10; MobileBtn.Parent = ScreenGui
Instance.new("UICorner", MobileBtn).CornerRadius = UDim.new(0,12)
local mobileStroke = Instance.new("UIStroke", MobileBtn)
mobileStroke.Color = Theme.Accent; mobileStroke.Thickness = 2
MakeDraggable(MobileBtn)

local AimbotBtn = Instance.new("TextButton")
AimbotBtn.Size = UDim2.new(0,54,0,54); AimbotBtn.Position = UDim2.new(0,16,0.5,35)
AimbotBtn.BackgroundColor3 = Theme.AccentOff; AimbotBtn.Text = "AIM"
AimbotBtn.TextColor3 = Theme.Text; AimbotBtn.Font = Enum.Font.GothamBlack
AimbotBtn.TextSize = 13; AimbotBtn.ZIndex = 10; AimbotBtn.Parent = ScreenGui
Instance.new("UICorner", AimbotBtn).CornerRadius = UDim.new(0,12)
local aimbotStroke = Instance.new("UIStroke", AimbotBtn)
aimbotStroke.Color = Theme.AccentOff; aimbotStroke.Thickness = 2
MakeDraggable(AimbotBtn)

AimbotBtn.MouseButton1Click:Connect(function()
    Config.Aimbot = not Config.Aimbot
    TweenService:Create(AimbotBtn,TweenInfo.new(0.2),{BackgroundColor3=Config.Aimbot and Theme.AccentGreen or Theme.AccentOff}):Play()
    aimbotStroke.Color = Config.Aimbot and Theme.AccentGreen or Theme.AccentOff
    AimbotBtn.TextColor3 = Config.Aimbot and Color3.fromRGB(0,0,0) or Theme.Text
end)

local guiVisible = true
local function setGuiVisible(v)
    guiVisible = v; Main.Visible = v; MobileBtn.Visible = not v
end
CloseBtn.MouseButton1Click:Connect(function() setGuiVisible(false) end)
MobileBtn.MouseButton1Click:Connect(function() setGuiVisible(true) end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setGuiVisible(not guiVisible) end
    if input.KeyCode == Enum.KeyCode.P then
        Config.Aimbot = not Config.Aimbot
        TweenService:Create(AimbotBtn,TweenInfo.new(0.2),{BackgroundColor3=Config.Aimbot and Theme.AccentGreen or Theme.AccentOff}):Play()
        aimbotStroke.Color = Config.Aimbot and Theme.AccentGreen or Theme.AccentOff
        AimbotBtn.TextColor3 = Config.Aimbot and Color3.fromRGB(0,0,0) or Theme.Text
    end
end)

print("[BSS] Loaded | RightShift = Toggle GUI | P = Aimbot")
