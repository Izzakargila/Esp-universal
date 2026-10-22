--[[ 
    Fallen Survival | Advanced ESP GUI
    Executor: Delta
    Fitur: Tracer, Box, Chams, Name ESP, Distance, Color Picker
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Drawing = Drawing or nil

-- State Config
local Config = {
    ESP = true,
    Box = true,
    Tracer = true,
    Chams = true,
    Name = true,
    Distance = true,
    MaxDist = 1000,
    Color = Color3.fromRGB(255, 50, 50), -- Warna default
    TracerOrigin = "Bottom" -- "Bottom" / "Mouse"
}

-- Hapus GUI lama
local oldGui = game.CoreGui:FindFirstChild("FallenESP_GUI")
if oldGui then oldGui:Destroy() end

-- Container
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FallenESP_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

-- Variabel Drawing & Data
local espObjects = {} -- {[player] = {tracer, box, billboard, highlight}}

-- ======================
-- FUNGSI UTAMA ESP
-- ======================

local function createESP(player)
    if player == LocalPlayer then return end
    
    local function setup(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Head") then return end
        
        -- Hapus lama
        if espObjects[player] then
            for _, obj in pairs(espObjects[player]) do
                if typeof(obj) == "Instance" then obj:Destroy() 
                elseif typeof(obj) == "Drawing" then obj:Remove() end
            end
        end
        
        local data = {}
        
        -- CHAMS (Highlight)
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
        
        -- BILLBOARD (Name & Distance)
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
        textLabel.Text = player.Name
        data.billboard = billboard
        data.textLabel = textLabel
        
        -- BOX & TRACER (Pakai Drawing Library)
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
-- UPDATE LOOP
-- ======================

RunService.RenderStepped:Connect(function()
    for player, data in pairs(espObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        
        if hrp and head and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            
            -- Update Chams & Billboard
            if data.highlight then 
                data.highlight.Enabled = Config.Chams and Config.ESP and distance <= Config.MaxDist
            end
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
            
            -- Update Box & Tracer (Drawing)
            if data.box and data.tracer and Drawing then
                if Config.ESP and distance <= Config.MaxDist and (Config.Box or Config.Tracer) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    
                    if onScreen then
                        -- Hitung ukuran box berdasarkan jarak
                        local headScreen = Camera:WorldToViewportPoint(head.Position)
                        local height = math.abs(headScreen.Y - screenPos.Y) * 2
                        local width = height / 2
                        
                        local x = screenPos.X - width / 2
                        local y = screenPos.Y - height / 2
                        
                        -- Update Box
                        data.box.Visible = Config.Box
                        data.box.Size = Vector2.new(width, height)
                        data.box.Position = Vector2.new(x, y)
                        data.box.Color = Config.Color
                        
                        -- Update Tracer
                        data.tracer.Visible = Config.Tracer
                        data.tracer.Color = Config.Color
                        
                        local tracerStart
                        if Config.TracerOrigin == "Mouse" then
                            tracerStart = UserInputService:GetMouseLocation()
                        else
                            tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        end
                        
                        data.tracer.From = tracerStart
                        data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    else
                        data.box.Visible = false
                        data.tracer.Visible = false
                    end
                else
                    data.box.Visible = false
                    data.tracer.Visible = false
                end
            end
        else
            -- Matikan jika mati / jauh
            if data.highlight then data.highlight.Enabled = false end
            if data.billboard then data.billboard.Enabled = false end
            if data.box then data.box.Visible = false end
            if data.tracer then data.tracer.Visible = false end
        end
    end
end)

-- ======================
-- GUI BUILDER (MODERN)
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
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

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
        -- Siklus warna (RGB)
        local colors = {
            Color3.fromRGB(255, 50, 50),   -- Merah
            Color3.fromRGB(50, 255, 50),   -- Hijau
            Color3.fromRGB(50, 50, 255),   -- Biru
            Color3.fromRGB(255, 255, 50),  -- Kuning
            Color3.fromRGB(255, 50, 255),  -- Ungu
            Color3.fromRGB(255, 255, 255)  -- Putih
        }
        local current = Config.Color
        local nextColor = colors[1]
        for i, c in ipairs(colors) do
            if c == current then
                nextColor = colors[i % #colors + 1]
                break
            end
        end
        Config.Color = nextColor
        btn.BackgroundColor3 = nextColor
        callback(nextColor)
    end)
end

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 220, 0, 380)
Main.Position = UDim2.new(0.5, -110, 0.5, -190)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
MakeDraggable(Main)

-- Stroke
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Thickness = 1

-- Title Bar
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
TitleText.Text = "Fallen ESP"
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
    ScreenGui:Destroy()
    -- Matikan drawing
    for _, data in pairs(espObjects) do
        if data.box then data.box:Remove() end
        if data.tracer then data.tracer:Remove() end
    end
end)

-- Scroll Frame
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -45)
Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 350)
Scroll.Parent = Main

-- Layout
local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

-- Section 1: Visuals
local Section1 = Instance.new("TextLabel")
Section1.Size = UDim2.new(1, 0, 0, 20)
Section1.BackgroundTransparency = 1
Section1.Text = "VISUALS"
Section1.TextColor3 = Color3.fromRGB(100, 150, 255)
Section1.Font = Enum.Font.GothamBold
Section1.TextSize = 11
Section1.TextXAlignment = Enum.TextXAlignment.Left
Section1.Parent = Scroll

CreateToggle(Scroll, "Master ESP", Config.ESP, function(v) Config.ESP = v end)
CreateToggle(Scroll, "Box ESP", Config.Box, function(v) Config.Box = v end)
CreateToggle(Scroll, "Tracer ESP", Config.Tracer, function(v) Config.Tracer = v end)
CreateToggle(Scroll, "Chams (Highlight)", Config.Chams, function(v) Config.Chams = v end)
CreateToggle(Scroll, "Name & Distance", Config.Name, function(v) Config.Name = v; Config.Distance = v end)

-- Section 2: Settings
local Section2 = Instance.new("TextLabel")
Section2.Size = UDim2.new(1, 0, 0, 20)
Section2.BackgroundTransparency = 1
Section2.Text = "SETTINGS"
Section2.TextColor3 = Color3.fromRGB(100, 150, 255)
Section2.Font = Enum.Font.GothamBold
Section2.TextSize = 11
Section2.TextXAlignment = Enum.TextXAlignment.Left
Section2.Parent = Scroll

CreateColorPicker(Scroll, "ESP Color", function(c) Config.Color = c end)

-- Max Distance Slider (Manual)
local distFrame = Instance.new("Frame")
distFrame.Size = UDim2.new(1, -10, 0, 50)
distFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
distFrame.BorderSizePixel = 0
distFrame.Parent = Scroll
Instance.new("UICorner", distFrame).CornerRadius = UDim.new(0, 6)

local distLabel = Instance.new("TextLabel")
distLabel.Size = UDim2.new(1, -20, 0, 20)
distLabel.Position = UDim2.new(0, 10, 0, 5)
distLabel.BackgroundTransparency = 1
distLabel.Text = "Max Distance: " .. Config.MaxDist
distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
distLabel.Font = Enum.Font.GothamSemibold
distLabel.TextSize = 12
distLabel.TextXAlignment = Enum.TextXAlignment.Left
distLabel.Parent = distFrame

local distBox = Instance.new("TextBox")
distBox.Size = UDim2.new(1, -20, 0, 18)
distBox.Position = UDim2.new(0, 10, 0, 27)
distBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
distBox.Text = tostring(Config.MaxDist)
distBox.TextColor3 = Color3.fromRGB(255, 255, 255)
distBox.Font = Enum.Font.Gotham
distBox.TextSize = 11
distBox.Parent = distFrame
Instance.new("UICorner", distBox).CornerRadius = UDim.new(0, 4)

distBox.FocusLost:Connect(function()
    local num = tonumber(distBox.Text)
    if num then
        Config.MaxDist = num
        distLabel.Text = "Max Distance: " .. num
    else
        distBox.Text = tostring(Config.MaxDist)
    end
end)

-- Watermark
local Watermark = Instance.new("TextLabel")
Watermark.Size = UDim2.new(1, -20, 0, 20)
Watermark.Position = UDim2.new(0, 10, 1, -25)
Watermark.BackgroundTransparency = 1
Watermark.Text = "Developed by Zero"
Watermark.TextColor3 = Color3.fromRGB(80, 80, 90)
Watermark.Font = Enum.Font.Gotham
Watermark.TextSize = 10
Watermark.Parent = Main

-- Toggle GUI dengan tombol (opsional, buat nyembunyiin)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)
