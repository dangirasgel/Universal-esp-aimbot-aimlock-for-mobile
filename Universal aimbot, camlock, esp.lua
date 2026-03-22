-- Place in a LocalScript inside StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

-- Force Rayfield to work on mobile
getgenv().UseOrder = true
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua'))()

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

local function getClosestTarget(useTeamCheck, useWallCheck, fovRadius)
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
    camlockTarget = getClosestTarget(settings.camlockTeamCheck, settings.camlockWallCheck, settings.fovRadius)
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
    Info = "Hides ESP boxes for teammates.",
    CurrentValue = false,
    Flag = "ESPTeamToggle",
    Callback = function(val)
        settings.espTeamCheck = val
    end,
})

-------------------------------------------------
-- TAB 2: Camlock
-------------------------------------------------
local CamlockTab = Window:CreateTab("Camlock", 4483362458)

CamlockTab:CreateSection("Aimlock", false)

local CamlockToggle = CamlockTab:CreateToggle({
    Name = "Enable Camlock",
    Info = "Locks camera onto nearest player in FOV.",
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
    Info = "Pauses lock when target is behind a wall.",
    CurrentValue = false,
    Flag = "CamlockWallToggle",
    Callback = function(val)
        settings.camlockWallCheck = val
    end,
})

local CamlockTeamToggle = CamlockTab:CreateToggle({
    Name = "Team Check",
    Info = "Ignores teammates.",
    CurrentValue = false,
    Flag = "CamlockTeamToggle",
    Callback = function(val)
        settings.camlockTeamCheck = val
    end,
})

CamlockTab:CreateSection("FOV Settings", false)

local FOVVisibleToggle = CamlockTab:CreateToggle({
    Name = "Show FOV Circle",
    Info = "Shows the FOV circle. OFF by default.",
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
    Info = "Radius of the camlock FOV circle.",
    Range = {10, 400},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 120,
    Flag = "FOVSlider",
    Callback = function(val)
        settings.fovRadius = val
    end,
})

CamlockTab:CreateSlider({
    Name = "Lock Smoothness",
    Info = "How smoothly the camera moves to target.",
    Range = {1, 20},
    Increment = 1,
    Suffix = "",
    CurrentValue = 2,
    Flag = "CamlockSmoothSlider",
    Callback = function(val)
        settings.camlockSmooth = val / 100
    end,
})

-------------------------------------------------
-- TAB 3: Aimbot
-------------------------------------------------
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

AimbotTab:CreateSection("Aimbot", false)

local AimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    Info = "Instantly snaps aim to nearest player in FOV.",
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
            Content = val and "Aimbot is now active." or "Aimbot disabled.",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

AimbotTab:CreateSection("Filters", false)

local AimbotTeamToggle = AimbotTab:CreateToggle({
    Name = "Team Check",
    Info = "Ignores teammates.",
    CurrentValue = false,
    Flag = "AimbotTeamToggle",
    Callback = function(val)
        settings.aimbotTeamCheck = val
    end,
})

local AimbotWallToggle = AimbotTab:CreateToggle({
    Name = "Wall Check",
    Info = "Won't aim at players behind walls.",
    CurrentValue = false,
    Flag = "AimbotWallToggle",
    Callback = function(val)
        settings.aimbotWallCheck = val
    end,
})

local AimbotKillToggle = AimbotTab:CreateToggle({
    Name = "Kill Check",
    Info = "Skips dead players, re-targets next alive. Aimbot stays ON.",
    CurrentValue = true,
    Flag = "AimbotKillToggle",
    Callback = function(val)
        settings.aimbotKillCheck = val
    end,
})

AimbotTab:CreateSection("FOV Settings", false)

local AimbotFOVToggle = AimbotTab:CreateToggle({
    Name = "Show Aimbot FOV",
    Info = "Shows the aimbot FOV circle. OFF by default.",
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
    Info = "Only targets players within this screen radius.",
    Range = {10, 400},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 120,
    Flag = "AimbotFOVSlider",
    Callback = function(val)
        settings.aimbotFovRadius = val
    end,
})

-------------------------------------------------
-- TAB 4: Misc
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
            Content = "Loading Infinite Yield...",
            Duration = 3,
            Image = 4483362458,
        })
        task.spawn(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        end)
    end,
})

-------------------------------------------------
-- Main heartbeat
-------------------------------------------------
RunService.Heartbeat:Connect(function()
    local localChar = localPlayer.Character

    if settings.camlockEnabled then
        if not camlockTarget then
            camlockTarget = getClosestTarget(settings.camlockTeamCheck, settings.camlockWallCheck, settings.fovRadius)
            targetVisible = false
        else
            local character = camlockTarget.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            if not character or not hum or hum.Health <= 0 then
                camlockTarget = getClosestTarget(settings.camlockTeamCheck, settings.camlockWallCheck, settings.fovRadius)
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
