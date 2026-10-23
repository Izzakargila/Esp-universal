--[[ 
    Brisk Survival Script | Premium UI Edition
    Features: Player ESP, Item ESP, Silent Aim, FOV Circle, Environment Mods
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Drawing = Drawing or nil

-- ======================
-- THEME & CONFIG
-- ======================
local Theme = {
    Background = Color3.fromRGB(12, 12, 15),
    TopBar = Color3.fromRGB(20, 20, 25),
    Element = Color3.fromRGB(28, 28, 35),
    ElementHover = Color3.fromRGB(38, 38, 48),
    Accent = Color3.fromRGB(138, 43, 226), -- Purple
    AccentOff = Color3.fromRGB(60, 60, 70),
    Text = Color3.fromRGB(240, 240, 245),
    TextDim = Color3.fromRGB(150, 150, 160)
}

local Config = {
    -- ESP
    ESP = true, Box = true, Tracer = true, Chams = true, Name = true, Distance = true, MaxDist = 1000,
    Color = Color3.fromRGB(255, 50, 50), TracerOrigin = "Bottom",
    ItemESP = true,
    -- Environment
    Fullbright = true, NoFog = true, NoWeather = true,
    -- Combat
    SilentAim = false, ShowFOV = true, FOV = 150
}

-- Cleanup old GUI
local oldGui = game.CoreGui:FindFirstChild("BriskSurvivalScript")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BriskSurvivalScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local espObjects = {}
local itemEspObjects = {}

-- ======================
-- FOV CIRCLE
-- ======================
local fovCircle
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.Color = Theme.Accent
    fovCircle.Filled = false
    fovCircle.Transparency = 0.8
    fovCircle.Visible = false
end

-- ======================
-- UTILITIES
-- ======================
local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ======================
-- COMBAT (SILENT AIM)
-- ======================
local function getClosestPlayer()
    local closest = nil
    local shortestDistance = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distToMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if distToMouse <= Config.FOV and distToMouse < shortestDistance then
                        shortestDistance = distToMouse
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if not checkcaller() and Config.SilentAim and (method == "FireServer" or method == "InvokeServer") then
        local remoteName = self.Name:lower()
        if remoteName:find("fire") or remoteName:find("shoot") or remoteName:find("hit") or remoteName:find("attack") or remoteName:find("weapon") or remoteName:find("damage") then
            local target = getClosestPlayer()
            if target and target.Character then
                local targetPart = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    if typeof(args[1]) == "Vector3" then
                        args[1] = targetPart.Position
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
    local success, result = pcall(oldNamecall, self, unpack(args))
    if success then return result else return oldNamecall(self, ...) end
end)

-- ======================
-- ENVIRONMENT LOGIC
-- ======================
local function applyEnvironment()
    if Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255); Lighting.Brightness = 2; Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(0, 0, 0); Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70); Lighting.Brightness = 1; Lighting.GlobalShadows = true
    end
    if Config.NoFog then Lighting.FogEnd = 1000000; Lighting.FogStart = 0 else Lighting.FogEnd = 1000; Lighting.FogStart = 0 end
    local atm = Lighting:FindFirstChildOfClass("Atmosphere"); local cld = Lighting:FindFirstChildOfClass("Clouds")
    if Config.NoWeather then
        if atm then atm:Destroy() end; if cld then cld:Destroy() end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") then
                local name = obj.Name:lower()
                if name:find("rain") or name:find("snow") or name:find("weather") or name:find("storm") then obj.Enabled = false end
            end
        end
    end
end

task.spawn(function() while task.wait(1) do pcall(applyEnvironment) end end)

-- ======================
-- ESP LOGIC
-- ======================
local function createESP(player)
    if player == LocalPlayer then return end
    local function setup(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Head") then return end
        if espObjects[player] then
            for _, obj in pairs(espObjects[player]) do
                if typeof(obj) == "Instance" then obj:Destroy() elseif typeof(obj) == "Drawing" then obj:Remove() end
            end
        end
        local data = {}
        local highlight = Instance.new("Highlight")
        highlight.Adornee = character; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.5; highlight.OutlineTransparency = 0; highlight.FillColor = Config.Color; highlight.OutlineColor = Config.Color
        highlight.Enabled = Config.Chams; highlight.Parent = character; data.highlight = highlight
        
        local billboard = Instance.new("BillboardGui")
        billboard.Adornee = character.Head; billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0); billboard.AlwaysOnTop = true; billboard.Enabled = Config.Name or Config.Distance; billboard.Parent = character.Head
        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboard; textLabel.BackgroundTransparency = 1; textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Font = Enum.Font.GothamBold; textLabel.TextColor3 = Config.Color; textLabel.TextStrokeTransparency = 0; textLabel.TextSize = 14
        data.billboard = billboard; data.textLabel = textLabel
        
        if Drawing then
            local box = Drawing.new("Square"); box.Visible = false; box.Color = Config.Color; box.Thickness = 1; box.Filled = false; data.box = box
            local tracer = Drawing.new("Line"); tracer.Visible = false; tracer.Color = Config.Color; tracer.Thickness = 1; data.tracer = tracer
        end
        espObjects[player] = data
    end
    player.CharacterAdded:Connect(setup)
    if player.Character then setup(player.Character) end
end

for _, p in pairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)

local LootNames = {"Loot", "Drop", "Item", "Crate", "Bag", "Weapon", "Gun", "Ammo", "Med", "Scrap", "Box"}
local function isLoot(obj)
    if not obj:IsA("BasePart") and not obj:IsA("Model") then return false end
    local name = obj.Name:lower()
    for _, keyword in ipairs(LootNames) do if name:find(keyword:lower()) then return true end end
    return false
end

RunService.Heartbeat:Connect(function()
    if not Config.ItemESP then
        for obj, data in pairs(itemEspObjects) do data.highlight:Destroy(); data.billboard:Destroy(); itemEspObjects[obj] = nil end
    else
        for _, obj in pairs(workspace:GetChildren()) do
            if isLoot(obj) and not itemEspObjects[obj] then
                local isCharacter = false
                for _, p in pairs(Players:GetPlayers()) do if p.Character == obj then isCharacter = true break end end
                if not isCharacter then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = obj; highlight.FillColor = Color3.fromRGB(255, 215, 0); highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = obj
                    local billboard = Instance.new("BillboardGui")
                    billboard.Adornee = obj; billboard.Size = UDim2.new(0, 100, 0, 50); billboard.AlwaysOnTop = true
                    local text = Instance.new("TextLabel")
                    text.Parent = billboard; text.BackgroundTransparency = 1; text.Size = UDim2.new(1, 0, 1, 0); text.TextColor3 = Color3.fromRGB(255, 215, 0)
                    text.TextStrokeTransparency = 0; text.Font = Enum.Font.GothamBold; text.TextSize = 12; text.Text = obj.Name; billboard.Parent = obj
                    itemEspObjects[obj] = {highlight = highlight, billboard = billboard}
                end
            end
        end
        for obj, data in pairs(itemEspObjects) do
            if not obj.Parent then data.highlight:Destroy(); data.billboard:Destroy(); itemEspObjects[obj] = nil end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if fovCircle then
        if Config.SilentAim and Config.ShowFOV then
            fovCircle.Visible = true; fovCircle.Position = UserInputService:GetMouseLocation(); fovCircle.Radius = Config.FOV
        else fovCircle.Visible = false end
    end

    for player, data in pairs(espObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        
        if hrp and head and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            if data.highlight then data.highlight.Enabled = Config.Chams and Config.ESP and distance <= Config.MaxDist end
            if data.billboard then
                data.billboard.Enabled = (Config.Name or Config.Distance) and Config.ESP and distance <= Config.MaxDist
                if data.textLabel then
                    local txt = ""; if Config.Name then txt = player.Name end
                    if Config.Distance then if txt ~= "" then txt = txt .. " " end; txt = txt .. "[" .. math.floor(distance) .. "m]" end
                    data.textLabel.Text = txt
                end
            end
            if data.box and data.tracer and Drawing then
                if Config.ESP and distance <= Config.MaxDist and (Config.Box or Config.Tracer) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local headScreen = Camera:WorldToViewportPoint(head.Position)
                        local height = math.abs(headScreen.Y - screenPos.Y) * 2; local width = height / 2
                        data.box.Visible = Config.Box; data.box.Size = Vector2.new(width, height)
                        data.box.Position = Vector2.new(screenPos.X - width / 2, screenPos.Y - height / 2); data.box.Color = Config.Color
                        data.tracer.Visible = Config.Tracer; data.tracer.Color = Config.Color
                        local tracerStart = (Config.TracerOrigin == "Mouse") and UserInputService:GetMouseLocation() or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        data.tracer.From = tracerStart; data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    else
                        data.box.Visible = false; data.tracer.Visible = false
                    end
                else
                    if data.box then data.box.Visible = false end; if data.tracer then data.tracer.Visible = false end
                end
            end
        else
            if data.highlight then data.highlight.Enabled = false end; if data.billboard then data.billboard.Enabled = false end
            if data.box then data.box.Visible = false end; if data.tracer then data.tracer.Visible = false end
        end
    end
end)

-- ======================
-- PREMIUM GUI BUILDER
-- ======================
local function CreateToggle(parent, text, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Theme.Element
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn
    
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 34, 0, 18)
    pill.Position = UDim2.new(1, -46, 0.5, -9)
    pill.BackgroundColor3 = default and Theme.Accent or Theme.AccentOff
    pill.Parent = btn
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.Parent = pill
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    
    local state = default
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Element}):Play() end)
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.Accent or Theme.AccentOff}):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        callback(state)
    end)
end

local function CreateTextBox(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Theme.Element
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.TextDim
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -20, 0, 18)
    box.Position = UDim2.new(0, 12, 0, 26)
    box.BackgroundTransparency = 1
    box.Text = tostring(default)
    box.TextColor3 = Theme.Text
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Parent = frame
    
    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num) else box.Text = tostring(default) end
    end)
end

local function CreateColorPicker(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Theme.Element
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn
    
    local colorBox = Instance.new("Frame")
    colorBox.Size = UDim2.new(0, 20, 0, 20)
    colorBox.Position = UDim2.new(1, -32, 0.5, -10)
    colorBox.BackgroundColor3 = Config.Color
    colorBox.Parent = btn
    Instance.new("UICorner", colorBox).CornerRadius = UDim.new(0, 4)
    
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Element}):Play() end)
    
    btn.MouseButton1Click:Connect(function()
        local colors = {Color3.fromRGB(255, 50, 50), Color3.fromRGB(50, 255, 50), Color3.fromRGB(50, 50, 255), Color3.fromRGB(255, 255, 50), Color3.fromRGB(255, 50, 255), Color3.fromRGB(255, 255, 255)}
        local current = Config.Color; local nextColor = colors[1]
        for i, c in ipairs(colors) do if c == current then nextColor = colors[i % #colors + 1] break end end
        Config.Color = nextColor; colorBox.BackgroundColor3 = nextColor; callback(nextColor)
    end)
end

-- Floating Button (Minimize)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50); ToggleBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
ToggleBtn.BackgroundColor3 = Theme.Background; ToggleBtn.Text = "BSS"; ToggleBtn.TextColor3 = Theme.Accent
ToggleBtn.Font = Enum.Font.GothamBlack; ToggleBtn.TextSize = 16; ToggleBtn.Parent = ScreenGui; ToggleBtn.Visible = false
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 12)
local toggleStroke = Instance.new("UIStroke", ToggleBtn); toggleStroke.Color = Theme.Accent; toggleStroke.Thickness = 2
MakeDraggable(ToggleBtn)

-- Main Window
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 280, 0, 420); Main.Position = UDim2.new(0.5, -140, 0.5, -210)
Main.BackgroundColor3 = Theme.Background; Main.BorderSizePixel = 0; Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10); MakeDraggable
