--[[ 
    Brisk Survival V1 / Fallen Survival | Mega Script V2 (Fix Silent Aim + FOV Circle)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Drawing = Drawing or nil

local Config = {
    ESP = true, Box = true, Tracer = true, Chams = true, Name = true, Distance = true, MaxDist = 1000,
    Color = Color3.fromRGB(255, 50, 50), TracerOrigin = "Bottom",
    ItemESP = true,
    Fullbright = true, NoFog = true, NoWeather = true,
    SilentAim = false, ShowFOV = true, FOV = 150
}

local oldGui = game.CoreGui:FindFirstChild("FallenESP_GUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FallenESP_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local espObjects = {}
local itemEspObjects = {}

-- ======================
-- FOV CIRCLE (Lingkaran Putih di layar)
-- ======================
local fovCircle
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Filled = false
    fovCircle.Transparency = 0.8
    fovCircle.Visible = false
end

-- ======================
-- FUNGSI DRAG GUI
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
-- COMBAT (SILENT AIM & FOV) LOGIC
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
                    -- Hitung jarak antara mouse dan kepala musuh di layar
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
        -- Cek apakah remote ini untuk nembak/mukul
        local remoteName = self.Name:lower()
        if remoteName:find("fire") or remoteName:find("shoot") or remoteName:find("hit") or remoteName:find("attack") or remoteName:find("weapon") or remoteName:find("damage") then
            
            local target = getClosestPlayer()
            if target and target.Character then
                local targetPart = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    -- LOGIKA AMAN: Hanya ubah arah (Vector3/CFrame), jangan ubah titik asal
                    if typeof(args[1]) == "Vector3" then
                        -- Jika argumen 1 adalah target posisi
                        args[1] = targetPart.Position
                    elseif typeof(args[1]) == "CFrame" then
                        -- Jika argumen 1 adalah CFrame origin, kita ubah rotasinya agar menghadap target
                        args[1] = CFrame.lookAt(args[1].Position, targetPart.Position)
                    end
                    
                    -- Jika ada argumen kedua yang berupa arah (Direction)
                    if typeof(args[2]) == "Vector3" and typeof(args[1]) == "Vector3" then
                        local origin = args[1]
                        args[2] = (targetPart.Position - origin).Unit
                    end
                end
            end
        end
    end
    
    -- Pcall agar kalau error, game tidak crash (tetap nembak normal)
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

task.spawn(function()
    while task.wait(1) do pcall(applyEnvironment) end
end)

-- ======================
-- ESP LOGIC (Player & Item) & UPDATE LOOP
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
        highlight.Name = "FallenESP_Chams"; highlight.Adornee = character; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.5; highlight.OutlineTransparency = 0; highlight.FillColor = Config.Color; highlight.OutlineColor = Config.Color
        highlight.Enabled = Config.Chams; highlight.Parent = character; data.highlight = highlight
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "FallenESP_Billboard"; billboard.Adornee = character.Head; billboard.Size = UDim2.new(0, 200, 0, 50)
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
    -- Item ESP
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
    -- Update FOV Circle
    if fovCircle then
        if Config.SilentAim and Config.ShowFOV then
            fovCircle.Visible = true
            fovCircle.Position = UserInputService:GetMouseLocation()
            fovCircle.Radius = Config.FOV
        else
            fovCircle.Visible = false
        end
    end

    -- Update Player ESP
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
-- GUI BUILDER
-- ======================
local function CreateToggle(parent, text, default, callback)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, -10, 0, 30)
    btn.BackgroundColor3 = default and Color3.fromRGB(40, 40, 45) or Color3.fromRGB(25, 25, 30); btn.BorderSizePixel = 0
    btn.Text = "  " .. text .. (default and " [ON]" or " [OFF]")
    btn.TextColor3 = default and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 13; btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state; btn.Text = "  " .. text .. (state and " [ON]" or " [OFF]")
        btn.TextColor3 = state and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 40, 45) or Color3.fromRGB(25, 25, 30); callback(state)
    end)
end

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(0.1, 0, 0.2, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22); ToggleBtn.Text = "ESP"; ToggleBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
ToggleBtn.Font = Enum.Font.GothamBlack; ToggleBtn.TextSize = 14; ToggleBtn.Parent = ScreenGui; ToggleBtn.Visible = false
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)
local toggleStroke = Instance.new("UIStroke", ToggleBtn); toggleStroke.Color = Color3.fromRGB(0, 255, 100); toggleStroke.Thickness = 2
MakeDraggable(ToggleBtn)

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 220, 0, 480); Main.Position = UDim2.new(0.5, -110, 0.5, -240)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22); Main.BorderSizePixel = 0; Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8); MakeDraggable(Main)
local stroke = Instance.new("UIStroke", Main); stroke.Color = Color3.fromRGB(60, 60, 70); stroke.Thickness = 1

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1, 0, 0, 35); Title.BackgroundColor3 = Color3.fromRGB(25, 25, 32); Title.BorderSizePixel = 0; Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)
local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -40, 1, 0); TitleText.Position = UDim2.new(0, 12, 0, 0); TitleText.BackgroundTransparency = 1
TitleText.Text = "Mega Script V2"; TitleText.TextColor3 = Color3.fromRGB(255, 255, 255); TitleText.Font = Enum.Font.GothamBlack
TitleText.TextSize = 15; TitleText.TextXAlignment = Enum.TextXAlignment.Left; TitleText.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25); CloseBtn.Position = UDim2.new(1, -32, 0.5, -12.5); CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "X"; CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255); CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 12
CloseBtn.Parent = Title; Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false; ToggleBtn.Visible = true end)
ToggleBtn.MouseButton1Click:Connect(function() Main.Visible = true; ToggleBtn.Visible = false end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -45); Scroll.Position = UDim2.new(0, 10, 0, 40); Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0; Scroll.ScrollBarThickness = 3; Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 600); Scroll.Parent = Main
local Layout = Instance.new("UIListLayout"); Layout.Padding = UDim.new(0, 6); Layout.SortOrder = Enum.SortOrder.LayoutOrder; Layout.Parent = Scroll

-- COMBAT
local SectionC = Instance.new("TextLabel")
SectionC.Size = UDim2.new(1, 0, 0, 20); SectionC.BackgroundTransparency = 1; SectionC.Text = "COMBAT"
SectionC.TextColor3 = Color3.fromRGB(255, 50, 150); SectionC.Font = Enum.Font.GothamBold; SectionC.TextSize = 11; SectionC.TextXAlignment = Enum.TextXAlignment.Left; SectionC.Parent = Scroll

CreateToggle(Scroll, "Silent Aim", Config.SilentAim, function(v) Config.SilentAim = v end)
CreateToggle(Scroll, "Show FOV Circle", Config.ShowFOV, function(v) Config.ShowFOV = v end)

local fovFrame = Instance.new("Frame")
fovFrame.Size = UDim2.new(1, -10, 0, 50); fovFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); fovFrame.BorderSizePixel = 0; fovFrame.Parent = Scroll
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(0, 6)
local fovLabel = Instance.new("TextLabel")
fovLabel.Size = UDim2.new(1, -20, 0, 20); fovLabel.Position = UDim2.new(0, 10, 0, 5); fovLabel.BackgroundTransparency = 1
fovLabel.Text = "Aim FOV Size: " .. Config.FOV; fovLabel.TextColor3 = Color3.fromRGB(200, 200, 200); fovLabel.Font = Enum.Font.GothamSemibold; fovLabel.TextSize = 12; fovLabel.TextXAlignment = Enum.TextXAlignment.Left; fovLabel.Parent = fovFrame
local fovBox = Instance.new("TextBox")
fovBox.Size = UDim2.new(1, -20, 0, 18); fovBox.Position = UDim2.new(0, 10, 0, 27); fovBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
fovBox.Text = tostring(Config.FOV); fovBox.TextColor3 = Color3.fromRGB(255, 255, 255); fovBox.Font = Enum.Font.Gotham; fovBox.TextSize = 11; fovBox.Parent = fovFrame
Instance.new("UICorner", fovBox).CornerRadius = UDim.new(0, 4)
fovBox.FocusLost:Connect(function()
    local num = tonumber(fovBox.Text)
    if num then Config.FOV = num; fovLabel.Text = "Aim FOV Size: "
