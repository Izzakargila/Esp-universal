--[[ 
    Fallen Survival | Mega Script (Player ESP, Item ESP, Fullbright, No Fog, No Weather)
    Executor: Delta
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Drawing = Drawing or nil

-- State Config (Fitur baru ditambahkan di sini)
local Config = {
    ESP = true,
    Box = true,
    Tracer = true,
    Chams = true,
    Name = true,
    Distance = true,
    MaxDist = 1000,
    Color = Color3.fromRGB(255, 50, 50),
    TracerOrigin = "Bottom",
    -- Fitur Baru:
    ItemESP = true,
    Fullbright = true,
    NoFog = true,
    NoWeather = true
}

-- Hapus GUI lama kalau ada
local oldGui = game.CoreGui:FindFirstChild("FallenESP_GUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FallenESP_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local espObjects = {}
local itemEspObjects = {}

-- ======================
-- FUNGSI DRAG
-- ======================
local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.XOffset + delta.X, startPos.Y.Scale, startPos.YOffset + delta.Y)
        end
    end)
end

-- ======================
-- ENVIRONMENT LOGIC (Fullbright, Fog, Weather)
-- ======================
local function applyEnvironment()
    if Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end

    if Config.NoFog then
        Lighting.FogEnd = 1000000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
    end

    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    local cld = Lighting:FindFirstChildOfClass("Clouds")
    
    if Config.NoWeather then
        if atm then atm:Destroy() end
        if cld then cld:Destroy() end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") then
                local name = obj.Name:lower()
                if name:find("rain") or name:find("snow") or name:find("weather") or name:find("storm") then
                    obj.Enabled = false
                end
            end
        end
    end
end

-- Loop untuk menjaga environment tetap berubah
task.spawn(function()
    while task.wait(1) do
        pcall(applyEnvironment)
    end
end)

-- ======================
-- PLAYER ESP LOGIC
-- ======================
local function createESP(player)
    if player == LocalPlayer then return end
    local function setup(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Head") then return end
        if espObjects[player] then
            for _, obj in pairs(espObjects[player]) do
                if typeof(obj) == "Instance" then obj:Destroy() 
                elseif typeof(obj) == "Drawing" then obj:Remove() end
            end
        end
        local data = {}
        local highlight = Instance.new("Highlight")
        highlight.Name = "FallenESP_Chams"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.FillColor = Config.Color
        highlight.OutlineColor = Config.Color
        highlight.Enabled = Config.Chams
        highlight.Parent = character
        data.highlight = highlight
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "FallenESP_Billboard"
        billboard.Adornee = character.Head
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = Config.Name or Config.Distance
        billboard.Parent = character.Head
        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboard
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextColor3 = Config.Color
        textLabel.TextStrokeTransparency = 0
        textLabel.TextSize = 14
        data.billboard = billboard
        data.textLabel = textLabel
        
        if Drawing then
            local box = Drawing.new("Square")
            box.Visible = false
            box.Color = Config.Color
            box.Thickness = 1
            box.Filled = false
            data.box = box
            local tracer = Drawing.new("Line")
            tracer.Visible = false
            tracer.Color = Config.Color
            tracer.Thickness = 1
            data.tracer = tracer
        end
        espObjects[player] = data
    end
    player.CharacterAdded:Connect(setup)
    if player.Character then setup(player.Character) end
end

for _, p in pairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)

-- ======================
-- ITEM ESP LOGIC
-- ======================
local LootNames = {"Loot", "Drop", "Item", "Crate", "Bag", "Weapon", "Gun", "Ammo", "Med", "Scrap", "Box"}

local function isLoot(obj)
    if not obj:IsA("BasePart") and not obj:IsA("Model") then return false end
    local name = obj.Name:lower()
    for _, keyword in ipairs(LootNames) do
        if name:find(keyword:lower()) then return true end
    end
    return false
end

RunService.Heartbeat:Connect(function()
    if not Config.ItemESP then
        -- Hapus item ESP jika dimatikan
        for obj, data in pairs(itemEspObjects) do
            data.highlight:Destroy()
            data.billboard:Destroy()
            itemEspObjects[obj] = nil
        end
        return
    end

    for _, obj in pairs(workspace:GetChildren()) do
        if isLoot(obj) and not itemEspObjects[obj] then
            local isCharacter = false
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character == obj then isCharacter = true break end
            end
            if not isCharacter then
                local highlight = Instance.new("Highlight")
                highlight.Adornee = obj
                highlight.FillColor = Color3.fromRGB(255, 215, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.5
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = obj
                
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = obj
                billboard.Size = UDim2.new(0, 100, 0, 50)
                billboard.AlwaysOnTop = true
                
                local text = Instance.new("TextLabel")
                text.Parent = billboard
                text.BackgroundTransparency = 1
                text.Size = UDim2.new(1, 0, 1, 0)
                text.TextColor3 = Color3.fromRGB(255, 215, 0)
                text.TextStrokeTransparency = 0
                text.Font = Enum.Font.GothamBold
                text.TextSize = 12
                text.Text = obj.Name
                billboard.Parent = obj
                
                itemEspObjects[obj] = {highlight = highlight, billboard = billboard}
            end
        end
    end
    
    for obj, data in pairs(itemEspObjects) do
        if not obj.Parent then
            data.highlight:Destroy()
            data.billboard:Destroy()
            itemEspObjects[obj] = nil
        end
    end
end)

-- ======================
-- UPDATE LOOP PLAYER ESP
-- ======================
RunService.RenderStepped:Connect(function()
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
                    local txt = ""
                    if Config.Name then txt = player.Name end
                    if Config.Distance then 
                        if txt ~= "" then txt = txt .. " " end
                        txt = txt .. "[" .. math.floor(distance) .. "m]"
                    end
                    data.textLabel.Text = txt
                end
            end
            if data.box and data.tracer and Drawing then
                if Config.ESP and distance <= Config.MaxDist and (Config.Box or Config.Tracer) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local headScreen = Camera:WorldToViewportPoint(head.Position)
                        local height = math.abs(headScreen.Y - screenPos.Y) * 2
                        local width = height / 2
                        local x = screenPos.X - width / 2
                        local y = screenPos.Y - height / 2
                        
                        data.box.Visible = Config.Box
                        data.box.Size = Vector2.new(width, height)
                        data.box.Position = Vector2.new(x, y)
                        data.box.Color = Config.Color
                        
                        data.tracer.Visible = Config.Tracer
                        data.tracer.Color = Config.Color
                        
                        local tracerStart = (Config.TracerOrigin == "Mouse") and UserInputService:GetMouseLocation() or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        data.tracer.From = tracerStart
                        data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    else
                        data.box.Visible = false
                        data.tracer.Visible = false
                    end
                else
                    if data.box then data.box.Visible = false end
                    if data.tracer then data.tracer.Visible = false end
                end
            end
        else
            if data.highlight then data.highlight.Enabled = false end
            if data.billboard then data.billboard.Enabled = false end
            if data.box then data.box.Visible = false end
            if data.tracer then data.tracer.Visible = false end
        end
    end
end)

-- ======================
-- GUI BUILDER
-- ======================
local function CreateToggle(parent, text, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.BackgroundColor3 = default and Color3.fromRGB(40, 40, 45) or Color3.fromRGB(25, 25, 30)
    btn.BorderSizePixel = 0
    btn.Text = "  " .. text .. (default and " [ON]" or " [OFF]")
    btn.TextColor3 = default and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = "  " .. text .. (state and " [ON]" or " [OFF]")
        btn.TextColor3 = state and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(150, 150, 150)
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 40, 45) or Color3.fromRGB(25, 25, 30)
        callback(state)
    end)
end

local function CreateColorPicker(parent, text, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 13
    label.Parent = frame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 25, 0, 25)
    btn.Position = UDim2.new(1, -32, 0.5, -12.5)
    btn.BackgroundColor3 = Config.Color
    btn.Text = ""
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        local colors = {
            Color3.fromRGB(255, 50, 50), Color3.fromRGB(50, 255, 50), Color3.fromRGB(50, 50, 255),
            Color3.fromRGB(255, 255, 50), Color3.fromRGB(255, 50, 255), Color3.fromRGB(255, 255, 255)
        }
        local current = Config.Color
        local nextColor = colors[1]
        for i, c in ipairs(colors) do
            if c == current then nextColor = colors[i % #colors + 1] break end
        end
        Config.Color = nextColor
        btn.BackgroundColor3 = nextColor
        callback(nextColor)
    end)
end

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.2, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
ToggleBtn.Text = "ESP"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 14
ToggleBtn.Parent = ScreenGui
ToggleBtn.Visible = false
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)
local toggleStroke = Instance.new("UIStroke", ToggleBtn)
toggleStroke.Color = Color3.fromRGB(0, 255, 100)
toggleStroke.Thickness = 2
MakeDraggable(ToggleBtn)

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 220, 0, 420) -- Ukuran ditambah karena menu lebih banyak
Main.Position = UDim2.new(0.5, -110, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
MakeDraggable(Main)

local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Thickness = 1

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Title.BorderSizePixel = 0
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -40, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Mega ESP"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.GothamBlack
TitleText.TextSize = 15
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -12.5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Title
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    ToggleBtn.Visible = true
end)

ToggleBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    ToggleBtn.Visible = false
end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -45)
Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 500) -- Canvas diperpanjang
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

-- BAGIAN PLAYER ESP
local Section1 = Instance.new("TextLabel")
Section1.Size = UDim2.new(1, 0, 0, 20)
Section1.BackgroundTransparency = 1
Section1.Text = "PLAYER VISUALS"
Section1.TextColor3 = Color3.fromRGB(100, 150, 255)
Section1.Font = Enum.Font.GothamBold
Section1.TextSize = 11
Section1.TextXAlignment = Enum.TextXAlignment.Left
Section1.Parent = Scroll

CreateToggle(Scroll, "Master Player ESP", Config.ESP, function(v) Config.ESP = v end)
CreateToggle(Scroll, "Box ESP", Config.Box, function(v) Config.Box = v end)
CreateToggle(Scroll, "Tracer ESP", Config.Tracer, function(v) Config.Tracer = v end)
CreateToggle(Scroll, "Chams (Highlight)", Config.Chams, function(v) Config.Chams = v end)
CreateToggle(Scroll, "Name & Distance", Config.Name, function(v) Config.Name = v; Config.Distance = v end)

-- BAGIAN ITEM ESP
local Section2 = Instance.new("TextLabel")
Section2.Size = UDim2.new(1, 0, 0, 20)
Section2.BackgroundTransparency = 1
Section2.Text = "ITEM ESP"
Section2.TextColor3 = Color3.fromRGB(255, 215, 0)
Section2.Font = Enum.Font.GothamBold
Section2.TextSize = 11
Section2.TextXAlignment = Enum.TextXAlignment.Left
Section2.Parent = Scroll

CreateToggle(Scroll, "Item/Loot ESP", Config.ItemESP, function(v) Config.ItemESP = v end)

-- BAGIAN ENVIRONMENT
local Section3 = Instance.new("TextLabel")
Section3.Size = UDim2.new(1, 0, 0, 20)
Section3.BackgroundTransparency = 1
Section3.Text = "ENVIRONMENT"
Section3.TextColor3 = Color3.fromRGB(0, 255, 150)
Section3.Font = Enum.Font.GothamBold
Section3.TextSize = 11
Section3.TextXAlignment = Enum.TextXAlignment.Left
Section3.Parent = Scroll

CreateToggle(Scroll, "Fullbright", Config.Fullbright, function(v) Config.Fullbright = v end)
CreateToggle(Scroll, "No Fog", Config.NoFog, function(v) Config.NoFog = v end)
CreateToggle(Scroll, "No Weather", Config.NoWeather, function(v) Config.NoWeather = v end)

-- BAGIAN SETTINGS
local Section4 = Instance.new("TextLabel")
Section4.Size = UDim2.new(1, 0, 0, 20)
Section4.BackgroundTransparency = 1
Section4.Text = "SETTINGS"
Section4.TextColor3 = Color3.fromRGB(100, 150, 255)
Section4.Font = Enum.Font.GothamBold
Section4.TextSize = 11
Section4.TextXAlignment = Enum.TextXAlignment.Left
Section4.Parent = Scroll

CreateColorPicker(Scroll, "Player Color", function(c) Config.Color = c end)

-- Max Distance Box
local distFrame = Instance.new("F
