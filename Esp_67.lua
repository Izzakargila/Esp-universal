--[[ Brisk Survival Script — Config Manager Edition (Part 1/3) ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Drawing = Drawing or nil

local Theme = {
    Background = Color3.fromRGB(12, 12, 16), SideBar = Color3.fromRGB(18, 18, 24),
    Element = Color3.fromRGB(28, 28, 36), ElementHover = Color3.fromRGB(42, 42, 54),
    Accent = Color3.fromRGB(0, 180, 255), AccentGreen = Color3.fromRGB(0, 220, 120),
    AccentRed = Color3.fromRGB(255, 60, 60), AccentOff = Color3.fromRGB(55, 55, 68),
    Text = Color3.fromRGB(240, 240, 245), TextDim = Color3.fromRGB(130, 130, 145)
}

local Config = {
    ESP = true, Box = true, Tracer = true, Chams = true, Name = true, Distance = true, 
    MaxDist = 5000, 
    Color = Color3.fromRGB(255, 50, 50),
    ItemESP = true, Fullbright = true, NoFog = true, NoWeather = true,
    SilentAim = false, ShowFOV = true, FOV = 150,
    Aimbot = false,
    TriggerBot = false, TriggerFOV = 200, TriggerDelay = 0.1,
    WallCheck = true
}

-- [ CONFIG MANAGER UTILS ]
local HttpService = game:GetService("HttpService")
local ConfigFolder = "BriskScript/Configs/"
if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end

local function saveConfig(name)
    if not writefile then return end
    local data = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then
            data[k] = {r = v.R, g = v.G, b = v.B, isColor = true}
        else
            data[k] = v
        end
    end
    local success, err = pcall(function()
        writefile(ConfigFolder .. name .. ".txt", HttpService:JSONEncode(data))
    end)
    if success then return true else return false end
end

local function loadConfig(name)
    if not isfile then return end
    local path = ConfigFolder .. name .. ".txt"
    if isfile(path) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if success and decoded then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    if type(v) == "table" and v.isColor then
                        Config[k] = Color3.new(v.r, v.g, v.b)
                    else
                        Config[k] = v
                    end
                end
            end
            return true
        end
    end
    return false
end

local function getConfigs()
    local list = {}
    if listfiles then
        for _, f in ipairs(listfiles(ConfigFolder)) do
            local name = f:match("([^/\\]+)%.txt$")
            if name then table.insert(list, name) end
        end
    end
    return list
end

-- Auto Load "default"
pcall(function()
    if isfile(ConfigFolder .. "default.txt") then
        loadConfig("default")
    end
end)

local oldGui = game.CoreGui:FindFirstChild("BriskSurvivalScript")
if oldGui then oldGui:Destroy() end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BriskSurvivalScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local fovCircle, triggerCircle
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5; fovCircle.Color = Theme.Accent
    fovCircle.Filled = false; fovCircle.Transparency = 0.75; fovCircle.Visible = false
    
    triggerCircle = Drawing.new("Circle")
    triggerCircle.Thickness = 1.5; triggerCircle.Color = Theme.AccentGreen
    triggerCircle.Filled = false; triggerCircle.Transparency = 0.75; triggerCircle.Visible = false
end

local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
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

local function hasLineOfSight(targetPart)
    if not Config.WallCheck then return true end
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

local function getClosestTarget(fovRadius)
    local closest, shortestDist = nil, math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, model in ipairs(workspace:GetChildren()) do
        if model ~= LocalPlayer.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
            if hum and head and hum.Health > 0 then
                if hasLineOfSight(head) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if dist <= fovRadius and dist < shortestDist then
                            shortestDist = dist; closest = model
                        end
                    end
                end
            end
        end
    end
    return closest
end
--[[ Part 2/3: Logic & Render Loop (Continuous Detection) ]]
local cachedTarget = nil
local cachedPart = nil
local lastTriggerTime = 0

RunService.Heartbeat:Connect(function()
    if Config.SilentAim then
        cachedTarget = getClosestTarget(Config.FOV)
        if cachedTarget then
            cachedPart = cachedTarget:FindFirstChild("Head") or cachedTarget:FindFirstChild("HumanoidRootPart")
        else
            cachedPart = nil
        end
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and Config.SilentAim and cachedPart then
        if method == "FireServer" or method == "InvokeServer" then
            local args = {...}
            for i, v in ipairs(args) do
                if typeof(v) == "Vector3" then args[i] = cachedPart.Position
                elseif typeof(v) == "CFrame" then args[i] = CFrame.lookAt(v.Position, cachedPart.Position)
                elseif typeof(v) == "Instance" and v:IsA("BasePart") then args[i] = cachedPart end
            end
            return oldNamecall(self, table.unpack(args))
        end
    end
    return oldNamecall(self, ...)
end)

local function applyEnvironment()
    if Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2; Lighting.GlobalShadows = false
    end
    if Config.NoFog then Lighting.FogEnd = 1e6; Lighting.FogStart = 0 end
    if Config.NoWeather then
        local atm = Lighting:FindFirstChildOfClass("Atmosphere"); local cld = Lighting:FindFirstChildOfClass("Clouds")
        if atm then atm:Destroy() end; if cld then cld:Destroy() end
    end
end
task.spawn(function() while task.wait(2) do pcall(applyEnvironment) end end)

-- ESP SYSTEM
local espObjects = {}
local itemEspObjects = {}

local function createESP(model)
    if not model or not model:IsA("Model") or model == LocalPlayer.Character then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local hrp = model:FindFirstChild("HumanoidRootPart")
    local head = model:FindFirstChild("Head")
    if not hrp or not head then return end
    
    if espObjects[model] then
        for _, obj in pairs(espObjects[model]) do
            if typeof(obj) == "Instance" then obj:Destroy() elseif typeof(obj) == "Drawing" then obj:Remove() end
        end
    end
    
    local data = {}
    local highlight = Instance.new("Highlight")
    highlight.Adornee = model; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.5; highlight.OutlineTransparency = 0; highlight.FillColor = Config.Color; highlight.OutlineColor = Config.Color
    highlight.Enabled = Config.Chams; highlight.Parent = model; data.highlight = highlight
    
    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = head; billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0); billboard.AlwaysOnTop = true; billboard.Enabled = Config.Name; billboard.Parent = head
    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard; textLabel.BackgroundTransparency = 1; textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Font = Enum.Font.GothamBold; textLabel.TextColor3 = Config.Color; textLabel.TextStrokeTransparency = 0; textLabel.TextSize = 14
    data.billboard = billboard; data.textLabel = textLabel
    
    if Drawing then
        local box = Drawing.new("Square"); box.Visible = false; box.Color = Config.Color; box.Thickness = 1; box.Filled = false; data.box = box
        local tracer = Drawing.new("Line"); tracer.Visible = false; tracer.Color = Config.Color; tracer.Thickness = 1; data.tracer = tracer
    end
    espObjects[model] = data
end

-- BACKGROUND SCANNER (Loop Deteksi Musuh/Player Baru)
task.spawn(function()
    while task.wait(1) do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                -- Kalau ada model yang punya Humanoid, HRP, dan belum didaftarkan
                if hum and hrp and hum.Health > 0 and not espObjects[obj] then
                    createESP(obj)
                end
            end
        end
    end
end)

-- Item ESP Task
task.spawn(function()
    while task.wait(2) do
        if Config.ItemESP then
            local LootNames = {"Loot", "Drop", "Item", "Crate", "Bag", "Weapon", "Gun", "Ammo", "Med", "Scrap", "Box"}
            for _, obj in ipairs(workspace:GetChildren()) do
                if (obj:IsA("BasePart") or obj:IsA("Model")) and not itemEspObjects[obj] then
                    local isLoot = false; local name = obj.Name:lower()
                    for _, keyword in ipairs(LootNames) do if name:find(keyword:lower()) then isLoot = true break end end
                    if isLoot then
                        local highlight = Instance.new("Highlight")
                        highlight.Adornee = obj; highlight.FillColor = Color3.fromRGB(255, 215, 0); highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.FillTransparency = 0.5; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = obj
                        itemEspObjects[obj] = highlight
                    end
                end
            end
            for obj, highlight in pairs(itemEspObjects) do
                if not obj.Parent then highlight:Destroy(); itemEspObjects[obj] = nil end
            end
        else
            for obj, highlight in pairs(itemEspObjects) do highlight:Destroy(); itemEspObjects[obj] = nil end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if fovCircle then
        local showFov = (Config.SilentAim or Config.Aimbot) and Config.ShowFOV
        fovCircle.Visible = showFov
        if showFov then
            fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            fovCircle.Radius = Config.FOV
        end
    end
    if triggerCircle then
        triggerCircle.Visible = Config.TriggerBot
        if Config.TriggerBot then
            triggerCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            triggerCircle.Radius = Config.TriggerFOV
        end
    end

    if Config.Aimbot and not Config.SilentAim then
        local target = getClosestTarget(Config.FOV)
        if target then
            local targetPart = target:FindFirstChild("Head")
            if targetPart and (Camera.CFrame.Position - targetPart.Position).Magnitude > 5 then 
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position) 
            end
        end
    end

    if Config.TriggerBot then
        local triggerTarget = getClosestTarget(Config.TriggerFOV)
        if triggerTarget then
            if tick() - lastTriggerTime > Config.TriggerDelay then
                local character = LocalPlayer.Character
                local tool = character and character:FindFirstChildOfClass("Tool")
                if tool and tool.Parent == character then
                    pcall(function() tool:Activate() end) 
                    lastTriggerTime = tick()
                end
            end
        end
    end

    -- Render ESP
    for model, data in pairs(espObjects) do
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local head = model:FindFirstChild("Head")
        
        if hum and hum.Health > 0 and hrp and head and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            
            if distance <= Config.MaxDist then
                if data.highlight then data.highlight.Enabled = Config.Chams and Config.ESP end
                if data.billboard then
                    data.billboard.Enabled = Config.Name and Config.ESP
                    if data.textLabel then
                        local displayName = model.Name
                        if Players:GetPlayerFromCharacter(model) then displayName = Players:GetPlayerFromCharacter(model).Name end
                        local txt = displayName
                        if Config.Distance then txt = txt .. " [" .. math.floor(distance) .. "m]" end
                        data.textLabel.Text = txt
                    end
                end
                
                if data.box and data.tracer and Drawing and Config.ESP then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local headScreen = Camera:WorldToViewportPoint(head.Position)
                        local height = math.abs(headScreen.Y - screenPos.Y) * 2; local width = height / 2
                        data.box.Visible = Config.Box; data.box.Size = Vector2.new(width, height)
                        data.box.Position = Vector2.new(screenPos.X - width / 2, screenPos.Y - height / 2); data.box.Color = Config.Color
                        data.tracer.Visible = Config.Tracer; data.tracer.Color = Config.Color
                        data.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    else
                        data.box.Visible = false; data.tracer.Visible = false
                    end
                end
            else
                if data.highlight then data.highlight.Enabled = false end
                if data.billboard then data.billboard.Enabled = false end
                if data.box then data.box.Visible = false end
                if data.tracer then data.tracer.Visible = false end
            end
        else
            if data.highlight then data.highlight.Enabled = false end
            if data.billboard then data.billboard.Enabled = false end
            if data.box then data.box.Visible = false end
            if data.tracer then data.tracer.Visible = false end
            
            -- Auto Cleanup jika model hancur/mati
            if not model.Parent or not hum or hum.Health <= 0 then
                if data.highlight then data.highlight:Destroy() end
                if data.billboard then data.billboard:Destroy() end
                if data.box then data.box:Remove() end
                if data.tracer then data.tracer:Remove() end
                espObjects[model] = nil
            end
        end
    end
end)
--[[ Part 3/3: GUI & Floating Buttons + Config Manager ]]
local function CreateToggle(parent, text, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,34); btn.BackgroundColor3 = Theme.Element; btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-54,1,0); lbl.Position = UDim2.new(0,12,0,0); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = btn
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0,32,0,17); pill.Position = UDim2.new(1,-42,0.5,-8.5); pill.BackgroundColor3 = default and Theme.Accent or Theme.AccentOff; pill.Parent = btn
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,13,0,13); circle.Position = default and UDim2.new(1,-15,0.5,-6.5) or UDim2.new(0,2,0.5,-6.5)
    circle.BackgroundColor3 = Color3.fromRGB(255,255,255); circle.Parent = pill
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
    local state = default
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Element}):Play() end)
    
    _G.UpdateToggles = _G.UpdateToggles or {}
    _G.UpdateToggles[text] = function(newState)
        state = newState
        TweenService:Create(pill,TweenInfo.new(0.2),{BackgroundColor3=state and Theme.Accent or Theme.AccentOff}):Play()
        TweenService:Create(circle,TweenInfo.new(0.2),{Position=state and UDim2.new(1,-15,0.5,-6.5) or UDim2.new(0,2,0.5,-6.5)}):Play()
    end

    btn.MouseButton1Click:Connect(function()
        state = not state
        _G.UpdateToggles[text](state)
        callback(state)
    end)
end

local function CreateSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame"); frame.Size = UDim2.new(1,0,0,50); frame.BackgroundColor3 = Theme.Element; frame.BorderSizePixel = 0; frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,7)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,-20,0,20); lbl.Position = UDim2.new(0,10,0,4); lbl.BackgroundTransparency = 1
    lbl.Text = text..": "..tostring(default); lbl.TextColor3 = Theme.Text; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 11; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = frame
    local track = Instance.new("Frame"); track.Size = UDim2.new(1,-20,0,6); track.Position = UDim2.new(0,10,0,32); track.BackgroundColor3 = Theme.AccentOff; track.BorderSizePixel = 0; track.Parent = frame
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame"); fill.Size = UDim2.new((default-min)/(max-min),0,1,0); fill.BackgroundColor3 = Theme.Accent; fill.BorderSizePixel = 0; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,12,0,12); knob.Position = UDim2.new((default-min)/(max-min),-6,0.5,-6); knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos)
        fill.Size = UDim2.new(pos,0,1,0); knob.Position = UDim2.new(pos,-6,0.5,-6); lbl.Text = text..": "..tostring(value)
        callback(value)
    end
    track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; update(input) end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
end

-- Button Builder untuk Config
local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,34); btn.BackgroundColor3 = Theme.Element; btn.BorderSizePixel = 0; btn.Text = text
    btn.TextColor3 = Theme.Text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Element}):Play() end)
    btn.MouseButton1Click:Connect(callback)
end

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50); ToggleBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
ToggleBtn.BackgroundColor3 = Theme.Background; ToggleBtn.Text = "BSS"; ToggleBtn.TextColor3 = Theme.Accent
ToggleBtn.Font = Enum.Font.GothamBlack; ToggleBtn.TextSize = 16; ToggleBtn.Parent = ScreenGui; ToggleBtn.Visible = false
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 12)
local toggleStroke = Instance.new("UIStroke", ToggleBtn); toggleStroke.Color = Theme.Accent; toggleStroke.Thickness = 2
MakeDraggable(ToggleBtn)

local QuickAimBtn = Instance.new("TextButton")
QuickAimBtn.Size = UDim2.new(0, 80, 0, 35); QuickAimBtn.Position = UDim2.new(0.05, 0, 0.3, 0)
QuickAimBtn.BackgroundColor3 = Config.Aimbot and Theme.AccentGreen or Theme.AccentRed
QuickAimBtn.Text = Config.Aimbot and "AIM: ON" or "AIM: OFF"
QuickAimBtn.TextColor3 = Theme.Text; QuickAimBtn.Font = Enum.Font.GothamBold; QuickAimBtn.TextSize = 12
QuickAimBtn.Parent = ScreenGui
Instance.new("UICorner", QuickAimBtn).CornerRadius = UDim.new(0, 8)
local quickAimStroke = Instance.new("UIStroke", QuickAimBtn); quickAimStroke.Color = Config.Aimbot and Theme.AccentGreen or Theme.AccentRed; quickAimStroke.Thickness = 2
MakeDraggable(QuickAimBtn)

local function updateQuickAimVisual()
    QuickAimBtn.Text = Config.Aimbot and "AIM: ON" or "AIM: OFF"
    QuickAimBtn.BackgroundColor3 = Config.Aimbot and Theme.AccentGreen or Theme.AccentRed
    quickAimStroke.Color = Config.Aimbot and Theme.AccentGreen or Theme.AccentRed
    if _G.UpdateToggles and _G.UpdateToggles["Instant Aimbot (Lock)"] then _G.UpdateToggles["Instant Aimbot (Lock)"](Config.Aimbot) end
end

QuickAimBtn.MouseButton1Click:Connect(function()
    Config.Aimbot = not Config.Aimbot
    if Config.Aimbot then Config.SilentAim = false end
    updateQuickAimVisual()
end)

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 450, 0, 260); Main.Position = UDim2.new(0.5, -225, 0.5, -130)
Main.BackgroundColor3 = Theme.Background; Main.BorderSizePixel = 0; Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10); MakeDraggable(Main)
local mainStroke = Instance.new("UIStroke", Main); mainStroke.Color = Theme.Accent; mainStroke.Thickness = 1.5; mainStroke.Transparency = 0.25

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1,0,0,36); TopBar.BackgroundColor3 = Theme.SideBar; TopBar.BorderSizePixel = 0; TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0,10)
local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1,0,0,10); topFix.Position = UDim2.new(0,0,1,-10); topFix.BackgroundColor3 = Theme.SideBar; topFix.BorderSizePixel = 0; topFix.Parent = TopBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1,-80,1,0); TitleText.Position = UDim2.new(0,14,0,0); TitleText.BackgroundTransparency = 1
TitleText.Text = "⚡ Brisk Survival Script"; TitleText.TextColor3 = Theme.Text; TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13; TitleText.TextXAlignment = Enum.TextXAlignment.Left; TitleText.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,24,0,24); CloseBtn.Position = UDim2.new(1,-30,0.5,-12); CloseBtn.BackgroundColor3 = Theme.AccentRed
CloseBtn.Text = "✕"; CloseBtn.TextColor3 = Theme.Text; CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 11; CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,6)

CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false; ToggleBtn.Visible = true; QuickAimBtn.Visible = true end)
ToggleBtn.MouseButton1Click:Connect(function() Main.Visible = true; ToggleBtn.Visible = false; QuickAimBtn.Visible = false end)

local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0,110,1,-36); SideBar.Position = UDim2.new(0,0,0,36); SideBar.BackgroundColor3 = Theme.SideBar; SideBar.BorderSizePixel = 0; SideBar.Parent = Main
local sideFix = Instance.new("Frame")
sideFix.Size = UDim2.new(0,10,1,0); sideFix.Position = UDim2.new(1,-10,0,0); sideFix.BackgroundColor3 = Theme.SideBar; sideFix.BorderSizePixel = 0; sideFix.Parent = SideBar
local SideLayout = Instance.new("UIListLayout"); SideLayout.Padding = UDim.new(0,5); SideLayout.SortOrder = Enum.SortOrder.LayoutOrder; SideLayout.Parent = SideBar
local SidePadding = Instance.new("UIPadding"); SidePadding.PaddingTop = UDim.new(0,10); SidePadding.PaddingLeft = UDim.new(0,8); SidePadding.PaddingRight = UDim.new(0,8); SidePadding.Parent = SideBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1,-110,1,-36); ContentArea.Position = UDim2.new(0,110,0,36); ContentArea.BackgroundTransparency = 1; ContentArea.Parent = Main

local Pages = {}
local function CreateTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,30); btn.BackgroundColor3 = Theme.Element; btn.Text = name
    btn.TextColor3 = Theme.TextDim; btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12; btn.Parent = SideBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1,-20,1,-10); page.Position = UDim2.new(0,10,0,5); page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Theme.Accent; page.CanvasSize = UDim2.new(0,0,0,0); page.Visible = false; page.Parent = ContentArea
    local pageLayout = Instance.new("UIListLayout"); pageLayout.Padding = UDim.new(0,6); pageLayout.Parent = page
    Pages[name] = {Btn = btn, Page = page, Layout = pageLayout}
    btn.MouseButton1Click:Connect(function()
        for n, obj in pairs(Pages) do
            if n == name then
                obj.Page.Visible = true
                TweenService:Create(obj.Btn,TweenInfo.new(0.2),{BackgroundColor3=Theme.Accent, TextColor3=Theme.Text}):Play()
            else
                obj.Page.Visible = false
                TweenService:Create(obj.Btn,TweenInfo.new(0.2),{BackgroundColor3=Theme.Element, TextColor3=Theme.TextDim}):Play()
            end
        end
    end)
    if index == 1 then page.Visible = true; btn.BackgroundColor3 = Theme.Accent; btn.TextColor3 = Theme.Text end
end

CreateTab("Combat", 1); CreateTab("Visuals", 2); CreateTab("Misc", 3); CreateTab("Configs", 4)

-- COMBAT TAB
CreateToggle(Pages["Combat"].Page, "Wall Check (Aim/Trigger)", Config.WallCheck, function(v) Config.WallCheck = v end)
CreateToggle(Pages["Combat"].Page, "Instant Aimbot (Lock)", Config.Aimbot, function(v) Config.Aimbot = v; if v then Config.SilentAim = false end; updateQuickAimVisual() end)
CreateToggle(Pages["Combat"].Page, "Silent Aim (Remote)", Config.SilentAim, function(v) Config.SilentAim = v; if v then Config.Aimbot = false; updateQuickAimVisual() end end)
CreateToggle(Pages["Combat"].Page, "Trigger Bot", Config.TriggerBot, function(v) Config.TriggerBot = v end)
CreateSlider(Pages["Combat"].Page, "Trigger Bot FOV", 10, 500, Config.TriggerFOV, function(v) Config.TriggerFOV = v end)
CreateSlider(Pages["Combat"].Page, "Trigger Delay (ms)", 50, 500, Config.TriggerDelay * 1000, function(v) Config.TriggerDelay = v / 1000 end)
CreateToggle(Pages["Combat"].Page, "Show FOV Circle", Config.ShowFOV, function(v) Config.ShowFOV = v end)
CreateSlider(Pages["Combat"].Page, "Aimbot/Silent FOV", 50, 500, Config.FOV, function(v) Config.FOV = v end)

-- VISUALS TAB
CreateToggle(Pages["Visuals"].Page, "Master Player ESP", Config.ESP, function(v) Config.ESP = v end)
CreateToggle(Pages["Visuals"].Page, "Box ESP", Config.Box, function(v) Config.Box = v end)
CreateToggle(Pages["Visuals"].Page, "Tracer ESP", Config.Tracer, function(v) Config.Tracer = v end)
CreateToggle(Pages["Visuals"].Page, "Chams (Highlight)", Config.Chams, function(v) Config.Chams = v end)
CreateToggle(Pages["Visuals"].Page, "Name & Distance", Config.Name, function(v) Config.Name = v; Config.Distance = v end)
CreateToggle(Pages["Visuals"].Page, "Item/Loot ESP", Config.ItemESP, function(v) Config.ItemESP = v end)
CreateSlider(Pages["Visuals"].Page, "Max ESP Distance", 500, 10000, Config.MaxDist, function(v) Config.MaxDist = v end)

-- MISC TAB
CreateToggle(Pages["Misc"].Page, "Fullbright", Config.Fullbright, function(v) Config.Fullbright = v end)
CreateToggle(Pages["Misc"].Page, "No Fog", Config.NoFog, function(v) Config.NoFog = v end)
CreateToggle(Pages["Misc"].Page, "No Weather", Config.NoWeather, function(v) Config.NoWeather = v end)

-- CONFIGS TAB
local ConfigNameBox = Instance.new("TextBox")
ConfigNameBox.Size = UDim2.new(1,0,0,35); ConfigNameBox.BackgroundColor3 = Theme.Element; ConfigNameBox.BorderSizePixel = 0
ConfigNameBox.Text = "Nama Config..."; ConfigNameBox.TextColor3 = Theme.TextDim; ConfigNameBox.Font = Enum.Font.GothamMedium; ConfigNameBox.TextSize = 12
ConfigNameBox.Parent = Pages["Configs"].Page
Instance.new("UICorner", ConfigNameBox).CornerRadius = UDim.new(0,7)
ConfigNameBox.Focused:Connect(function() ConfigNameBox.Text = ""; ConfigNameBox.TextColor3 = Theme.Text end)

local function GetConfigName()
    local n = ConfigNameBox.Text
    if n == "" or n == "Nama Config..." then return "default" end
    return n
end

CreateButton(Pages["Configs"].Page, "💾 Save Config", function()
    local name = GetConfigName()
    local ok = saveConfig(name)
    if ok then
        if _G.Notify then _G.Notify("Config", "Berhasil menyimpan: "..name, 3) end
    else
        if _G.Notify then _G.Notify("Config", "Gagal save (Executor tidak support)", 3) end
    end
end)

CreateButton(Pages["Configs"].Page, "📂 Load Config", function()
    local name = GetConfigName()
    local ok = loadConfig(name)
    if ok then
        if _G.Notify then _G.Notify("Config", "Berhasil memuat: "..name, 3) end
        -- Refresh GUI Text (Hacky way)
        for text, func in pairs(_G.UpdateToggles) do
            if Config[text:gsub(" %b()",""):gsub(" ","")] ~= nil then
                -- Bisa di-refresh manual jika diperlukan
            end
        end
    else
        if _G.Notify then _G.Notify("Config", "Config tidak ditemukan", 3) end
    end
end)

CreateButton(Pages["Configs"].Page, "📤 Export / Share Config", function()
    local name = GetConfigName()
    local path = ConfigFolder .. name .. ".txt"
    if isfile(path) then
        local contents = readfile(path)
        if setclipboard then
            setclipboard(contents)
            if _G.Notify then _G.Notify("Config", "Config disalin ke Clipboard! Kirim ke temanmu.", 3) end
        else
            if _G.Notify then _G.Notify("Config", "Executor tidak support copy", 3) end
        end
    else
        if _G.Notify then _G.Notify("Config", "Config tidak ada, save dulu!", 3) end
    end
end)

CreateButton(Pages["Configs"].Page, "📥 Import Config", function()
    local name = GetConfigName()
    if getclipboard and writefile then
        local clip = getclipboard()
        if clip and clip:find("{") then
            writefile(ConfigFolder .. name .. ".txt", clip)
            if _G.Notify then _G.Notify("Config", "Berhasil import config: "..name, 3) end
        else
            if _G.Notify then _G.Notify("Config", "Clipboard kosong / bukan config valid", 3) end
        end
    end
end)

-- Buat fungsi Notify sederhana (Toast)
_G.Notify = function(title, text, duration)
    local notif = Instance.new("TextLabel")
    notif.Size = UDim2.new(0, 300, 0, 50)
    notif.Position = UDim2.new(0.5, -150, 0, -60)
    notif.BackgroundColor3 = Theme.SideBar
    notif.TextColor3 = Theme.Text
    notif.Text = "🔔 " .. title .. ": " .. text
    notif.Font = Enum.Font.GothamBold
    notif.TextSize = 12
    notif.Parent = ScreenGui
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", notif); stroke.Color = Theme.Accent
    
    TweenService:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -150, 0, 20)}):Play()
    task.delay(duration or 3, function()
        TweenService:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -150, 0, -60)}):Play()
        task.wait(0.3)
        notif:Destroy()
    end)
end

for _, t in pairs(Pages) do
    t.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        t.Page.CanvasSize = UDim2.new(0, 0, 0, t.Layout.AbsoluteContentSize.Y + 10)
    end)
end
