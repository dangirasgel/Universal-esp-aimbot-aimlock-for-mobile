-- Place in a LocalScript inside StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local settings = {
    espEnabled = false,
    espTeamCheck = false,
    camlockEnabled = false,
    camlockWallCheck = false,
    camlockTeamCheck = false,
    fovVisible = false,
    fovRadius = 120,
    camlockSmooth = 0.08,
    aimbotEnabled = false,
    aimbotTeamCheck = false,
    aimbotWallCheck = false,
    aimbotKillCheck = true,
    aimbotFovRadius = 120,
    aimbotFovVisible = false,
    triggerbotEnabled = false,
    triggerbotWallCheck = false,
}

local MAX_DISTANCE = 500
local BOX_COLOR = Color3.fromRGB(255, 0, 0)
local TEAM_COLOR = Color3.fromRGB(0, 150, 255)
local FOV_COLOR = Color3.fromRGB(255, 255, 255)
local FOV_LOCKED_COLOR = Color3.fromRGB(255, 220, 0)
local AIMBOT_FOV_COLOR = Color3.fromRGB(255, 255, 255)
local AIMBOT_FOV_ACTIVE_COLOR = Color3.fromRGB(255, 220, 0)

local targetVisible = false
local aimbotVisible = false
local camlockTarget = nil
local espObjects = {}
local configName = ""
local configDropdown = nil
local selectedConfig = ""

local espGui = Instance.new("ScreenGui")
espGui.Name = "BoxESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espGui.Parent = localPlayer.PlayerGui

local FOV_SEGMENTS = 360

local function createCircle(parent, color)
    local segs = {}
    for i = 1, FOV_SEGMENTS do
        local seg = Instance.new("Frame")
        seg.BackgroundColor3 = color
        seg.BorderSizePixel = 0
        seg.AnchorPoint = Vector2.new(0.5, 0.5)
        seg.ZIndex = 10
        seg.Visible = false
        seg.Parent = parent
        segs[i] = seg
    end
    return segs
end

local function updateCircle(segs, cx, cy, r, color, visible)
    for i = 1, FOV_SEGMENTS do
        segs[i].Visible = visible
        if not visible then continue end
        local a1 = ((i - 1) / FOV_SEGMENTS) * math.pi * 2
        local a2 = (i / FOV_SEGMENTS) * math.pi * 2
        local x1 = cx + math.cos(a1) * r
        local y1 = cy + math.sin(a1) * r
        local x2 = cx + math.cos(a2) * r
        local y2 = cy + math.sin(a2) * r
        local dx = x2 - x1
        local dy = y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)
        segs[i].Position = UDim2.new(0, (x1 + x2) / 2, 0, (y1 + y2) / 2)
        segs[i].Size = UDim2.new(0, len + 2, 0, 2)
        segs[i].Rotation = math.deg(angle)
        segs[i].BackgroundColor3 = color
    end
end

local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVFrame"
fovFrame.BackgroundTransparency = 1
fovFrame.BorderSizePixel = 0
fovFrame.Size = UDim2.new(1, 0, 1, 0)
fovFrame.ZIndex = 10
fovFrame.Parent = espGui
local camlockSegs = createCircle(fovFrame, FOV_COLOR)

local aimbotFovFrame = Instance.new("Frame")
aimbotFovFrame.Name = "AimbotFOVFrame"
aimbotFovFrame.BackgroundTransparency = 1
aimbotFovFrame.BorderSizePixel = 0
aimbotFovFrame.Size = UDim2.new(1, 0, 1, 0)
aimbotFovFrame.ZIndex = 10
aimbotFovFrame.Parent = espGui
local aimbotSegs = createCircle(aimbotFovFrame, AIMBOT_FOV_COLOR)

local function updateCamlockFOV()
    local cx = camera.ViewportSize.X / 2
    local cy = camera.ViewportSize.Y / 2
    local color = (settings.camlockEnabled and targetVisible) and FOV_LOCKED_COLOR or FOV_COLOR
    updateCircle(camlockSegs, cx, cy, settings.fovRadius, color, settings.fovVisible)
end

local function updateAimbotFOV()
    local cx = camera.ViewportSize.X / 2
    local cy = camera.ViewportSize.Y / 2
    local color = (settings.aimbotEnabled and aimbotVisible) and AIMBOT_FOV_ACTIVE_COLOR or AIMBOT_FOV_COLOR
    updateCircle(aimbotSegs, cx, cy, settings.aimbotFovRadius, color, settings.aimbotFovVisible)
end

local function canSeeTarget(fromChar, toCharacter)
    local fromHRP = fromChar:FindFirstChild("HumanoidRootPart")
    local toHRP = toCharacter:FindFirstChild("HumanoidRootPart")
    if not fromHRP or not toHRP then return false end
    local origin = fromHRP.Position
    local direction = toHRP.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {fromChar, toCharacter}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

local function isSameTeam(player)
    return localPlayer.Team ~= nil and player.Team == localPlayer.Team
end

local function getHP(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then return math.floor(hum.Health), math.floor(hum.MaxHealth) end
    return 0, 100
end

local function getHPColor(pct)
    if pct > 0.6 then return Color3.fromRGB(0, 255, 80)
    elseif pct > 0.3 then return Color3.fromRGB(255, 180, 0)
    else return Color3.fromRGB(255, 50, 50) end
end

local function getDistance(character)
    local lc = localPlayer.Character
    if not lc then return 0 end
    local lr = lc:FindFirstChild("HumanoidRootPart")
    local or2 = character:FindFirstChild("HumanoidRootPart")
    if lr and or2 then
        return math.floor((lr.Position - or2.Position).Magnitude)
    end
    return 0
end

local function getClosestInFOV(useTeamCheck, useWallCheck, fovRadius)
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closest = nil
    local closestDist = math.huge
    local localChar = localPlayer.Character
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if useTeamCheck and localPlayer.Team ~= nil and player.Team == localPlayer.Team then continue end
        local character = player.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local hum = character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end
        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if screenDist > fovRadius then continue end
        if useWallCheck and localChar then
            if not canSeeTarget(localChar, character) then continue end
        end
        if screenDist < closestDist then
            closestDist = screenDist
            closest = player
        end
    end
    return closest
end

local function getAimbotTarget()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closest = nil
    local closestDist = math.huge
    local localChar = localPlayer.Character
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if settings.aimbotTeamCheck and localPlayer.Team ~= nil and player.Team == localPlayer.Team then continue end
        local character = player.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local hum = character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then continue end
        if settings.aimbotKillCheck and hum.Health <= 0 then continue end
        local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end
        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if screenDist > settings.aimbotFovRadius then continue end
        if settings.aimbotWallCheck and localChar then
            if not canSeeTarget(localChar, character) then continue end
        end
        if screenDist < closestDist then
            closestDist = screenDist
            closest = player
        end
    end
    return closest
end

-------------------------------------------------
-- Triggerbot
-------------------------------------------------
local function isAnyPlayerOnCrosshair()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local localChar = localPlayer.Character
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local character = player.Character
        if not character then continue end
        local hum = character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local parts = {
            character:FindFirstChild("Head"),
            character:FindFirstChild("HumanoidRootPart"),
            character:FindFirstChild("UpperTorso"),
            character:FindFirstChild("Torso"),
        }
        for _, part in ipairs(parts) do
            if not part then continue end
            local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            if (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude < 25 then
                if settings.triggerbotWallCheck then
                    if localChar and canSeeTarget(localChar, character) then
                        return true
                    end
                else
                    return true
                end
            end
        end
    end
    return false
end

task.spawn(function()
    while true do
        if settings.triggerbotEnabled and UserInputService.WindowFocused then
            if isAnyPlayerOnCrosshair() then
                pcall(mouse1click)
                task.wait(0.016)
            else
                task.wait(0.01)
            end
        else
            task.wait(0.1)
        end
    end
end)

-------------------------------------------------
-- Config system
-------------------------------------------------
local configFolder = "AepxyzoHub"
local HttpService = game:GetService("HttpService")

local function ensureFolder()
    pcall(function()
        if not isfolder(configFolder) then
            makefolder(configFolder)
        end
    end)
end

local function getConfigPath(name)
    return configFolder .. "/" .. name .. ".json"
end

local function saveConfig(name)
    ensureFolder()
    local data = {}
    for k, v in pairs(settings) do
        data[k] = v
    end
    local ok = pcall(function()
        writefile(getConfigPath(name), HttpService:JSONEncode(data))
    end)
    return ok
end

local function loadConfig(name)
    ensureFolder()
    local path = getConfigPath(name)
    local exists = false
    pcall(function() exists = isfile(path) end)
    if not exists then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if settings[k] ~= nil then
                settings[k] = v
            end
        end
        return true
    end
    return false
end

local function deleteConfig(name)
    ensureFolder()
    local path = getConfigPath(name)
    local ok = false
    pcall(function()
        if isfile(path) then
            delfile(path)
            ok = true
        end
    end)
    return ok
end

local function getConfigList()
    ensureFolder()
    local list = {}
    pcall(function()
        for _, f in ipairs(listfiles(configFolder)) do
            local name = f:match("([^/\\]+)%.json$")
            if name then
                table.insert(list, name)
            end
        end
    end)
    return list
end

local function refreshDropdown()
    if not configDropdown then return end
    pcall(function()
        local list = getConfigList()
        if #list > 0 then
            configDropdown:Refresh(list, list[1])
            selectedConfig = list[1]
        else
            configDropdown:Refresh({"No configs"}, "No configs")
            selectedConfig = ""
        end
    end)
end

local function createPlayerESP(player)
    local container = Instance.new("Frame")
    container.Name = player.Name
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(0, 0, 0, 0)
    container.Visible = false
    container.Parent = espGui

    for _, data in ipairs({
        {size = UDim2.new(1,0,0,2),  pos = UDim2.new(0,0,0,0)},
        {size = UDim2.new(1,0,0,2),  pos = UDim2.new(0,0,1,-2)},
        {size = UDim2.new(0,2,1,0),  pos = UDim2.new(0,0,0,0)},
        {size = UDim2.new(0,2,1,0),  pos = UDim2.new(1,-2,0,0)},
    }) do
        local f = Instance.new("Frame")
        f.BackgroundColor3 = BOX_COLOR
        f.BorderSizePixel = 0
        f.Size = data.size
        f.Position = data.pos
        f.Parent = container
    end

    local hpBg = Instance.new("Frame")
    hpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    hpBg.BorderSizePixel = 0
    hpBg.Size = UDim2.new(0, 4, 1, 0)
    hpBg.Position = UDim2.new(0, -6, 0, 0)
    hpBg.Parent = container

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HPFill"
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 80)
    hpFill.BorderSizePixel = 0
    hpFill.AnchorPoint = Vector2.new(0, 1)
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.Position = UDim2.new(0, 0, 1, 0)
    hpFill.Parent = hpBg

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.Position = UDim2.new(0, 0, 0, -18)
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Text = player.Name
    nameLabel.Parent = container

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 0, 14)
    infoLabel.Position = UDim2.new(0, 0, 1, 4)
    infoLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    infoLabel.TextStrokeTransparency = 0
    infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Center
    infoLabel.Parent = container

    return container
end

local function addPlayer(player)
    if player == localPlayer then return end
    espObjects[player] = createPlayerESP(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
    end)
end

local function enableCamlock()
    settings.camlockEnabled = true
    camlockTarget = getClosestInFOV(settings.camlockTeamCheck, settings.camlockWallCheck, settings.fovRadius)
    targetVisible = false
end

local function disableCamlock()
    settings.camlockEnabled = false
    camlockTarget = nil
    targetVisible = false
end

-------------------------------------------------
-- Rayfield Window
-------------------------------------------------
local Window = Rayfield:CreateWindow({
    Name = "Credits To Aepxyzo on Discord",
    LoadingTitle = "Credits To Aepxyzo on Discord",
    LoadingSubtitle = "Loading...",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "ESPConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = false
    },
    KeySystem = false,
    KeySettings = {
        Title = "",
        Subtitle = "",
        Note = "",
        FileName = "",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = ""
    }
})

-------------------------------------------------
-- TAB 1: ESP
-------------------------------------------------
local ESPTab = Window:CreateTab("ESP", 4483362458)
ESPTab:CreateSection("Visuals", false)

local ESPToggle = ESPTab:CreateToggle({
    Name = "Enable ESP",
    Info = "Shows player boxes through walls.",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(val)
        settings.espEnabled = val
        if not val then
            for _, c in pairs(espGui:GetChildren()) do
                if c.Name ~= "FOVFrame" and c.Name ~= "AimbotFOVFrame" then
                    c.Visible = false
                end
            end
        end
    end,
})

local ESPTeamToggle = ESPTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "ESPTeamToggle",
    Callback = function(val) settings.espTeamCheck = val end,
})

ESPTab:CreateSection("Keybinds", false)

ESPTab:CreateKeybind({
    Name = "Toggle ESP",
    CurrentKeybind = "Z",
    HoldToInteract = false,
    Flag = "ESPKeybind",
    Callback = function()
        local v = not settings.espEnabled
        settings.espEnabled = v
        ESPToggle:Set(v)
        if not v then
            for _, c in pairs(espGui:GetChildren()) do
                if c.Name ~= "FOVFrame" and c.Name ~= "AimbotFOVFrame" then
                    c.Visible = false
                end
            end
        end
    end,
})

ESPTab:CreateKeybind({
    Name = "Toggle Team Check",
    CurrentKeybind = "X",
    HoldToInteract = false,
    Flag = "ESPTeamKeybind",
    Callback = function()
        local v = not settings.espTeamCheck
        settings.espTeamCheck = v
        ESPTeamToggle:Set(v)
    end,
})

-------------------------------------------------
-- TAB 2: Camlock
-------------------------------------------------
local CamlockTab = Window:CreateTab("Camlock", 4483362458)
CamlockTab:CreateSection("Aimlock", false)

local CamlockToggle = CamlockTab:CreateToggle({
    Name = "Enable Camlock",
    CurrentValue = false,
    Flag = "CamlockToggle",
    Callback = function(val)
        if val then
            enableCamlock()
            Rayfield:Notify({
                Title = "Cam Lock ON",
                Content = camlockTarget and ("Locked: " .. camlockTarget.Name) or "Searching...",
                Duration = 2,
                Image = 4483362458,
            })
        else
            disableCamlock()
            Rayfield:Notify({
                Title = "Cam Lock OFF",
                Content = "Camlock disabled.",
                Duration = 2,
                Image = 4483362458,
            })
        end
    end,
})

CamlockTab:CreateSection("Filters", false)

local CamlockWallToggle = CamlockTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = false,
    Flag = "CamlockWallToggle",
    Callback = function(val) settings.camlockWallCheck = val end,
})

local CamlockTeamToggle = CamlockTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "CamlockTeamToggle",
    Callback = function(val) settings.camlockTeamCheck = val end,
})

CamlockTab:CreateSection("FOV Settings", false)

CamlockTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = false,
    Flag = "FOVVisibleToggle",
    Callback = function(val)
        settings.fovVisible = val
        if not val then
            for i = 1, FOV_SEGMENTS do camlockSegs[i].Visible = false end
        end
    end,
})

CamlockTab:CreateSlider({
    Name = "FOV Radius",
    Range = {10, 400},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 120,
    Flag = "FOVSlider",
    Callback = function(val) settings.fovRadius = val end,
})

CamlockTab:CreateSlider({
    Name = "Lock Smoothness",
    Range = {1, 20},
    Increment = 1,
    Suffix = "",
    CurrentValue = 2,
    Flag = "CamlockSmoothSlider",
    Callback = function(val) settings.camlockSmooth = val / 100 end,
})

CamlockTab:CreateSection("Keybinds", false)

CamlockTab:CreateKeybind({
    Name = "Toggle Camlock",
    CurrentKeybind = "E",
    HoldToInteract = false,
    Flag = "CamlockKeybind",
    Callback = function()
        local v = not settings.camlockEnabled
        CamlockToggle:Set(v)
        if v then
            enableCamlock()
            Rayfield:Notify({
                Title = "Cam Lock ON",
                Content = camlockTarget and ("Locked: " .. camlockTarget.Name) or "Searching...",
                Duration = 2,
                Image = 4483362458,
            })
        else
            disableCamlock()
        end
    end,
})

-------------------------------------------------
-- TAB 3: Aimbot
-------------------------------------------------
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
AimbotTab:CreateSection("Aimbot", false)

local AimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(val)
        settings.aimbotEnabled = val
        if not val then
            aimbotVisible = false
            for i = 1, FOV_SEGMENTS do aimbotSegs[i].Visible = false end
        end
        Rayfield:Notify({
            Title = val and "Aimbot ON" or "Aimbot OFF",
            Content = val and "Aimbot active." or "Aimbot disabled.",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

AimbotTab:CreateSection("Filters", false)

local AimbotTeamToggle = AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "AimbotTeamToggle",
    Callback = function(val) settings.aimbotTeamCheck = val end,
})

local AimbotWallToggle = AimbotTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = false,
    Flag = "AimbotWallToggle",
    Callback = function(val) settings.aimbotWallCheck = val end,
})

local AimbotKillToggle = AimbotTab:CreateToggle({
    Name = "Kill Check",
    Info = "Skips dead players. Aimbot stays ON.",
    CurrentValue = true,
    Flag = "AimbotKillToggle",
    Callback = function(val) settings.aimbotKillCheck = val end,
})

AimbotTab:CreateSection("FOV Settings", false)

AimbotTab:CreateToggle({
    Name = "Show Aimbot FOV",
    CurrentValue = false,
    Flag = "AimbotFOVToggle",
    Callback = function(val)
        settings.aimbotFovVisible = val
        if not val then
            for i = 1, FOV_SEGMENTS do aimbotSegs[i].Visible = false end
        end
    end,
})

AimbotTab:CreateSlider({
    Name = "Aimbot FOV Radius",
    Range = {10, 400},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 120,
    Flag = "AimbotFOVSlider",
    Callback = function(val) settings.aimbotFovRadius = val end,
})

AimbotTab:CreateSection("Keybinds", false)

AimbotTab:CreateKeybind({
    Name = "Toggle Aimbot",
    CurrentKeybind = "F",
    HoldToInteract = false,
    Flag = "AimbotKeybind",
    Callback = function()
        local v = not settings.aimbotEnabled
        settings.aimbotEnabled = v
        AimbotToggle:Set(v)
        if not v then
            aimbotVisible = false
            for i = 1, FOV_SEGMENTS do aimbotSegs[i].Visible = false end
        end
        Rayfield:Notify({
            Title = v and "Aimbot ON" or "Aimbot OFF",
            Content = v and "Aimbot active." or "Aimbot disabled.",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

-------------------------------------------------
-- TAB 4: Triggerbot
-------------------------------------------------
local TriggerTab = Window:CreateTab("Triggerbot", 4483362458)
TriggerTab:CreateSection("Triggerbot", false)

local TriggerToggle = TriggerTab:CreateToggle({
    Name = "Enable Triggerbot",
    Info = "Auto fires when player is on crosshair. Only works when game is focused.",
    CurrentValue = false,
    Flag = "TriggerToggle",
    Callback = function(val)
        settings.triggerbotEnabled = val
        Rayfield:Notify({
            Title = val and "Triggerbot ON" or "Triggerbot OFF",
            Content = val and "Auto firing on crosshair targets." or "Triggerbot disabled.",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

TriggerTab:CreateSection("Filters", false)

TriggerTab:CreateToggle({
    Name = "Wall Check",
    Info = "Only fires when target is not behind a wall.",
    CurrentValue = false,
    Flag = "TriggerWallToggle",
    Callback = function(val)
        settings.triggerbotWallCheck = val
    end,
})

TriggerTab:CreateSection("Keybinds", false)

TriggerTab:CreateKeybind({
    Name = "Toggle Triggerbot",
    CurrentKeybind = "T",
    HoldToInteract = false,
    Flag = "TriggerKeybind",
    Callback = function()
        local v = not settings.triggerbotEnabled
        settings.triggerbotEnabled = v
        TriggerToggle:Set(v)
        Rayfield:Notify({
            Title = v and "Triggerbot ON" or "Triggerbot OFF",
            Content = v and "Auto firing on crosshair targets." or "Triggerbot disabled.",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

-------------------------------------------------
-- TAB 5: Misc + Config
-------------------------------------------------
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Misc", false)

MiscTab:CreateButton({
    Name = "INF YIELD",
    Info = "Loads the Infinite Yield admin script.",
    Interact = "Execute",
    Callback = function()
        Rayfield:Notify({
            Title = "Infinite Yield",
            Content = "Loading...",
            Duration = 3,
            Image = 4483362458,
        })
        task.spawn(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        end)
    end,
})

MiscTab:CreateSection("Config", false)

MiscTab:CreateInput({
    Name = "Config Name",
    Info = "Type a name then press Save.",
    PlaceholderText = "e.g. MyPreset",
    RemoveTextAfterFocusLost = false,
    Flag = "ConfigNameInput",
    Callback = function(text)
        configName = tostring(text)
    end,
})

MiscTab:CreateButton({
    Name = "Save Config",
    Info = "Saves current settings with the name above.",
    Interact = "Save",
    Callback = function()
        local name = configName
        if not name or name:gsub("%s", "") == "" then
            Rayfield:Notify({
                Title = "Error",
                Content = "Type a config name first.",
                Duration = 3,
                Image = 4483362458,
            })
            return
        end
        local ok = saveConfig(name)
        Rayfield:Notify({
            Title = ok and "Saved!" or "Error",
            Content = ok and ("Saved as: " .. name) or "Failed to save.",
            Duration = 3,
            Image = 4483362458,
        })
        if ok then
            task.wait(0.1)
            refreshDropdown()
        end
    end,
})

local initialList = getConfigList()
local dropdownOptions = #initialList > 0 and initialList or {"No configs"}
local dropdownDefault = dropdownOptions[1]
selectedConfig = dropdownDefault ~= "No configs" and dropdownDefault or ""

configDropdown = MiscTab:CreateDropdown({
    Name = "Select Config",
    Info = "Pick a saved config to load or delete.",
    Options = dropdownOptions,
    CurrentOption = dropdownDefault,
    Flag = "ConfigDropdown",
    Callback = function(option)
        if option ~= "No configs" then
            selectedConfig = option
        else
            selectedConfig = ""
        end
    end,
})

MiscTab:CreateButton({
    Name = "Load Config",
    Info = "Loads the selected config.",
    Interact = "Load",
    Callback = function()
        if selectedConfig == "" then
            Rayfield:Notify({
                Title = "Error",
                Content = "Select a config from the dropdown first.",
                Duration = 3,
                Image = 4483362458,
            })
            return
        end
        local ok = loadConfig(selectedConfig)
        Rayfield:Notify({
            Title = ok and "Loaded!" or "Error",
            Content = ok and ("Loaded: " .. selectedConfig) or "Config not found.",
            Duration = 3,
            Image = 4483362458,
        })
    end,
})

MiscTab:CreateButton({
    Name = "Delete Config",
    Info = "Deletes the selected config.",
    Interact = "Delete",
    Callback = function()
        if selectedConfig == "" then
            Rayfield:Notify({
                Title = "Error",
                Content = "Select a config from the dropdown first.",
                Duration = 3,
                Image = 4483362458,
            })
            return
        end
        local ok = deleteConfig(selectedConfig)
        Rayfield:Notify({
            Title = ok and "Deleted!" or "Error",
            Content = ok and ("Deleted: " .. selectedConfig) or "Config not found.",
            Duration = 3,
            Image = 4483362458,
        })
        if ok then
            selectedConfig = ""
            task.wait(0.1)
            refreshDropdown()
        end
    end,
})

-------------------------------------------------
-- Main heartbeat
-------------------------------------------------
RunService.Heartbeat:Connect(function()
    local localChar = localPlayer.Character

    if settings.camlockEnabled then
        if not camlockTarget then
            camlockTarget = getClosestInFOV(settings.camlockTeamCheck, settings.camlockWallCheck, settings.fovRadius)
            targetVisible = false
        else
            local character = camlockTarget.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            if not character or not hum or hum.Health <= 0 then
                camlockTarget = getClosestInFOV(settings.camlockTeamCheck, settings.camlockWallCheck, settings.fovRadius)
                targetVisible = false
            else
                local canSee = not settings.camlockWallCheck or (localChar ~= nil and canSeeTarget(localChar, character))
                targetVisible = canSee
                if canSee then
                    local head = character:FindFirstChild("Head")
                    local aimPart = head or character:FindFirstChild("HumanoidRootPart")
                    if aimPart then
                        local currentCF = camera.CFrame
                        local lookCF = CFrame.lookAt(currentCF.Position, aimPart.Position)
                        camera.CFrame = currentCF:Lerp(lookCF, settings.camlockSmooth)
                    end
                end
            end
        end
    else
        targetVisible = false
    end

    if settings.aimbotEnabled then
        local target = getAimbotTarget()
        if target then
            local character = target.Character
            local head = character and character:FindFirstChild("Head")
            local aimPart = head or (character and character:FindFirstChild("HumanoidRootPart"))
            if aimPart then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPart.Position)
                aimbotVisible = true
            else
                aimbotVisible = false
            end
        else
            aimbotVisible = false
        end
    else
        aimbotVisible = false
    end

    updateCamlockFOV()
    updateAimbotFOV()

    for player, container in pairs(espObjects) do
        local character = player.Character
        if not settings.espEnabled or not character then
            container.Visible = false
            continue
        end
        if settings.espTeamCheck and isSameTeam(player) then
            container.Visible = false
            continue
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        if not hrp or not head then
            container.Visible = false
            continue
        end
        local dist = getDistance(character)
        if dist > MAX_DISTANCE then
            container.Visible = false
            continue
        end
        local topWorld = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.1, 0)
        local botWorld = hrp.Position - Vector3.new(0, 3, 0)
        local topScreen, topVisible = camera:WorldToViewportPoint(topWorld)
        local botScreen = camera:WorldToViewportPoint(botWorld)
        if not topVisible then
            container.Visible = false
            continue
        end
        container.Visible = true
        local boxH = math.abs(botScreen.Y - topScreen.Y)
        local boxW = boxH * 0.6
        container.Position = UDim2.new(0, topScreen.X - boxW / 2, 0, topScreen.Y)
        container.Size = UDim2.new(0, boxW, 0, boxH)
        local isCamlockTarget = (camlockTarget == player) and targetVisible
        local boxCol = isCamlockTarget and Color3.fromRGB(255, 220, 0)
            or (not settings.espTeamCheck and isSameTeam(player) and TEAM_COLOR or BOX_COLOR)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "HPFill" then
                child.BackgroundColor3 = boxCol
            end
        end
        local hp, maxHp = getHP(character)
        local pct = maxHp > 0 and (hp / maxHp) or 0
        local hpFill = container:FindFirstChild("HPFill", true)
        if hpFill then
            hpFill.Size = UDim2.new(1, 0, pct, 0)
            hpFill.BackgroundColor3 = getHPColor(pct)
        end
        local infoLabel = container:FindFirstChild("InfoLabel")
        if infoLabel then
            infoLabel.Text = hp .. " HP  |  " .. dist .. "m"
        end
    end
end)

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        espObjects[player]:Destroy()
        espObjects[player] = nil
    end
    if camlockTarget == player then
        camlockTarget = nil
        targetVisible = false
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    addPlayer(p)
end

print("Credits To Aepxyzo on Discord - Loaded!")
