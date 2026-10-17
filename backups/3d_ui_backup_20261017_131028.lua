-- LocalScript à¸ªà¸³à¸«à¸£à¸±à¸šà¸£à¸±à¸™à¸œà¹ˆà¸²à¸™ Executor / Client Environment
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

local function getGuiParent()
    if gethui then
        local success, res = pcall(gethui)
        if success and res then return res end
    end
    return player:WaitForChild("PlayerGui")
end
local targetGuiParent = getGuiParent()

-- ====================================================================
-- Universal Variables & States
-- ====================================================================
local speedEnabled, currentSpeed, defaultSpeed = false, 16, 16
local jumpEnabled, currentJump, defaultJump = false, 50, 50
local noclipEnabled = false
local infJumpEnabled = false
local flyEnabled, flySpeed = false, 50
local espEnabled = false
local fullbrightEnabled = false
local antiAfkEnabled = false

-- Bhop System
local bhopEnabled = false
local autoJumpActive = false
local bhopMomentum = 16
local JUMP_INITIAL_BOOST = 4.5
local STRAFE_BOOST_AIR = 0.45
local GROUND_MOMENTUM_LOSS = 0.96

local MAX_STRAIGHT_SPEED = 55.5
local MAX_BHOP_SPEED = 135
local STRAIGHT_BLEED_RATE = 10.0

local lastCameraYaw = 0
local isStrafing = false

-- Camlock System Variables (Post-Camera Priority Lock)
local camlockEnabled = false
local isTargetLocked = false
local lockedTargetPart = nil
local CAMLOCK_SMOOTHNESS = 0.25 -- à¸„à¸§à¸²à¸¡à¹€à¸™à¸µà¸¢à¸™à¹ƒà¸™à¸à¸²à¸£à¹€à¸¥à¹‡à¸‡à¹€à¸›à¹‰à¸² (0.15 - 0.4)
local CAMLOCK_MAX_DIST = 250

local MAX_DISTANCE = 50
local SPAWN_DISTANCE = 3.0

local interactionState = "IDLE"
local isAnimating = false
local isUIVisible = false

local wasMainUIVisibleBeforeWardrobe = false
local previousCameraType = nil
local previousCameraCFrame = nil
local savedOriginalRootCFrame = nil

local savedZoomDistance = nil
local wasAlreadyFirstPerson = false

local mobileFlyUp = false
local mobileFlyDown = false

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHead()
    local char = player.Character
    return char and char:FindFirstChild("Head")
end

local function isCurrentlyFirstPerson()
    local head = getHead()
    if head then
        local distToHead = (camera.CFrame.Position - head.Position).Magnitude
        if distToHead <= 0.85 or head.LocalTransparencyModifier > 0.5 then
            return true, distToHead
        end
        return false, distToHead
    end
    return false, 10
end

local function getFacingCFrame(targetPosition)
    return CFrame.lookAt(targetPosition, camera.CFrame.Position)
end

local function calculateCameraFrontPosition()
    local camPos = camera.CFrame.Position
    local lookVec = camera.CFrame.LookVector
    local upVec = camera.CFrame.UpVector
    return camPos + (lookVec * SPAWN_DISTANCE) - (upVec * 0.25)
end

-- ====================================================================
-- Universal Forward Declarations (Shared UI Handles & Cross-Module Functions)
-- Solves Luau's 200 local registers per chunk limit
-- ====================================================================
local screenHudGui, hudContainer, hudStroke, speedNumLabel, unitLabel, gaugeFill
local autoJumpBtn, autoJumpStroke, btnStatusText
local camlockBtn, camlockStroke, camlockStatusText
local setCamlockButtonVisible, updateCamlockButtonVisual

local uiPart, surfaceGui, backSurfaceGui, container, sidebar, mainFrame
local tabIndicator, titleLabel, closeBtn, minBtn, trackViewport, pagesTrack, grabBarContainer
local currentPartWidth, currentPartHeight = 4.8, 3.8
local typewriteTitle

local mobileGui, mobileFlyFrame
local flyAttachment, flyVelocity, flyAlign, startFly, stopFly
local updateESP, applyFullbright

local wardrobePart, wardrobeSurfaceGui, wardrobeBackSurfaceGui, wardrobeContainer, wardrobeMainWindow, wardrobeGrabBarContainer, wardrobeCloseBtn
local wardrobeVisualBar, visualBar, resizeHandle, line1, line2
local profileBtn, profileStroke
local restoreCharacterAppearance

local performZoomInAndAlign, performZoomOut
local summonUIWithAnimation, hideUIWithAnimation
local summonWardrobeWithAnimation, hideWardrobeWithAnimation
local updateToggleBtnState, cleanupOrbitController, setupOrbitController

-- ====================================================================
-- ScreenGui à¸ªà¸³à¸«à¸£à¸±à¸š HUD à¸•à¹ˆà¸²à¸‡à¹† à¸šà¸™à¸«à¸™à¹‰à¸²à¸ˆà¸­
-- ====================================================================
do
    screenHudGui = Instance.new("ScreenGui")
screenHudGui.Name = "SpatialUI_ScreenHUD"
screenHudGui.ResetOnSpawn = false
screenHudGui.DisplayOrder = 997
screenHudGui.Parent = targetGuiParent

-- [ 1. Speedometer HUD à¸‹à¹‰à¸²à¸¢à¸¥à¹ˆà¸²à¸‡ ]
hudContainer = Instance.new("CanvasGroup")
hudContainer.Name = "SpeedHUD"
hudContainer.Size = UDim2.new(0, 165, 0, 62)
hudContainer.Position = UDim2.new(0, 25, 1, 40)
hudContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
hudContainer.BackgroundTransparency = 0.3
hudContainer.BorderSizePixel = 0
hudContainer.GroupTransparency = 1
hudContainer.Visible = false
hudContainer.Parent = screenHudGui
Instance.new("UICorner", hudContainer).CornerRadius = UDim.new(0, 12)

hudStroke = Instance.new("UIStroke", hudContainer)
hudStroke.Color = Color3.fromRGB(50, 140, 255)
hudStroke.Thickness = 1.4
hudStroke.Transparency = 0.4

local hudAccentLine = Instance.new("Frame")
hudAccentLine.Size = UDim2.new(1, 0, 0, 2)
hudAccentLine.Position = UDim2.new(0, 0, 0, 0)
hudAccentLine.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
hudAccentLine.BorderSizePixel = 0
hudAccentLine.Parent = hudContainer

local hudTitle = Instance.new("TextLabel")
hudTitle.Size = UDim2.new(1, -20, 0, 16)
hudTitle.Position = UDim2.new(0, 12, 0, 7)
hudTitle.BackgroundTransparency = 1
hudTitle.Text = "VELOCITY // SPEED"
hudTitle.TextColor3 = Color3.fromRGB(150, 165, 195)
hudTitle.Font = Enum.Font.GothamBold
hudTitle.TextSize = 10
hudTitle.TextXAlignment = Enum.TextXAlignment.Left
hudTitle.Parent = hudContainer

speedNumLabel = Instance.new("TextLabel")
speedNumLabel.Size = UDim2.new(0, 75, 0, 28)
speedNumLabel.Position = UDim2.new(0, 12, 0, 20)
speedNumLabel.BackgroundTransparency = 1
speedNumLabel.Text = "16.0"
speedNumLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedNumLabel.Font = Enum.Font.GothamBold
speedNumLabel.TextSize = 22
speedNumLabel.TextXAlignment = Enum.TextXAlignment.Left
speedNumLabel.Parent = hudContainer

unitLabel = Instance.new("TextLabel")
unitLabel.Size = UDim2.new(0, 50, 0, 16)
unitLabel.Position = UDim2.new(0, 76, 0, 28)
unitLabel.BackgroundTransparency = 1
unitLabel.Text = "SPS"
unitLabel.TextColor3 = Color3.fromRGB(80, 180, 255)
unitLabel.Font = Enum.Font.GothamBold
unitLabel.TextSize = 11
unitLabel.TextXAlignment = Enum.TextXAlignment.Left
unitLabel.Parent = hudContainer

local gaugeBackground = Instance.new("Frame")
gaugeBackground.Size = UDim2.new(1, -24, 0, 4)
gaugeBackground.Position = UDim2.new(0, 12, 1, -11)
gaugeBackground.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
gaugeBackground.BorderSizePixel = 0
gaugeBackground.Parent = hudContainer
Instance.new("UICorner", gaugeBackground).CornerRadius = UDim.new(1, 0)

gaugeFill = Instance.new("Frame")
gaugeFill.Size = UDim2.new(0.1, 0, 1, 0)
gaugeFill.BackgroundColor3 = Color3.fromRGB(50, 160, 255)
gaugeFill.BorderSizePixel = 0
gaugeFill.Parent = gaugeBackground
Instance.new("UICorner", gaugeFill).CornerRadius = UDim.new(1, 0)

-- [ 2. à¸›à¸¸à¹ˆà¸¡ Auto Jump à¸à¸±à¹ˆà¸‡à¸‚à¸§à¸²à¸‚à¸­à¸‡à¸«à¸™à¹‰à¸²à¸ˆà¸­ ]
autoJumpBtn = Instance.new("TextButton")
autoJumpBtn.Name = "AutoJumpToggleBtn"
autoJumpBtn.Size = UDim2.new(0, 56, 0, 56)
autoJumpBtn.Position = UDim2.new(1, 30, 0.65, 0)
autoJumpBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
autoJumpBtn.BackgroundTransparency = 0.25
autoJumpBtn.Text = ""
autoJumpBtn.AutoButtonColor = false
autoJumpBtn.Visible = false
autoJumpBtn.Parent = screenHudGui
Instance.new("UICorner", autoJumpBtn).CornerRadius = UDim.new(0, 16)

autoJumpStroke = Instance.new("UIStroke", autoJumpBtn)
autoJumpStroke.Color = Color3.fromRGB(60, 60, 80)
autoJumpStroke.Thickness = 1.8

local btnTextTop = Instance.new("TextLabel")
btnTextTop.Size = UDim2.new(1, 0, 0, 16)
btnTextTop.Position = UDim2.new(0, 0, 0, 10)
btnTextTop.BackgroundTransparency = 1
btnTextTop.Text = "AUTO"
btnTextTop.TextColor3 = Color3.fromRGB(180, 180, 200)
btnTextTop.Font = Enum.Font.GothamBold
btnTextTop.TextSize = 11
btnTextTop.Parent = autoJumpBtn

btnStatusText = Instance.new("TextLabel")
btnStatusText.Size = UDim2.new(1, 0, 0, 18)
btnStatusText.Position = UDim2.new(0, 0, 0, 26)
btnStatusText.BackgroundTransparency = 1
btnStatusText.Text = "OFF"
btnStatusText.TextColor3 = Color3.fromRGB(140, 140, 160)
btnStatusText.Font = Enum.Font.GothamBold
btnStatusText.TextSize = 13
btnStatusText.Parent = autoJumpBtn

local function updateAutoJumpButtonVisual(active)
    if active then
        btnStatusText.Text = "ON"
        btnStatusText.TextColor3 = Color3.fromRGB(45, 220, 120)
        autoJumpStroke.Color = Color3.fromRGB(45, 220, 120)
        TweenService:Create(autoJumpBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 36, 28)}):Play()
    else
        btnStatusText.Text = "OFF"
        btnStatusText.TextColor3 = Color3.fromRGB(140, 140, 160)
        autoJumpStroke.Color = Color3.fromRGB(60, 60, 80)
        TweenService:Create(autoJumpBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(22, 22, 28)}):Play()
    end
end

autoJumpBtn.Activated:Connect(function()
    autoJumpActive = not autoJumpActive
    updateAutoJumpButtonVisual(autoJumpActive)
    autoJumpBtn.Size = UDim2.new(0, 52, 0, 52)
    TweenService:Create(autoJumpBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 56, 0, 56)
    }):Play()
end)

local function setBhopScreenWidgets(visible)
    if visible then
        hudContainer.Visible = true
        autoJumpBtn.Visible = true

        TweenService:Create(hudContainer, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 25, 1, -85),
            GroupTransparency = 0
        }):Play()

        TweenService:Create(autoJumpBtn, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -75, 0.65, 0)
        }):Play()
    else
        local tweenLeft = TweenService:Create(hudContainer, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 25, 1, 40),
            GroupTransparency = 1
        })
        local tweenRight = TweenService:Create(autoJumpBtn, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 30, 0.65, 0)
        })

        tweenLeft:Play()
        tweenRight:Play()

        tweenLeft.Completed:Connect(function()
            if not bhopEnabled then
                hudContainer.Visible = false
                autoJumpBtn.Visible = false
                autoJumpActive = false
                updateAutoJumpButtonVisual(false)
            end
        end)
    end
end

-- [ 3. à¸›à¸¸à¹ˆà¸¡ Camlock à¸•à¸´à¸”à¸«à¸™à¹‰à¸²à¸ˆà¸­à¸à¸±à¹ˆà¸‡à¸‚à¸§à¸² ]
camlockBtn = Instance.new("TextButton")
camlockBtn.Name = "CamlockTriggerBtn"
camlockBtn.Size = UDim2.new(0, 56, 0, 56)
camlockBtn.Position = UDim2.new(1, 30, 0.52, 0)
camlockBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
camlockBtn.BackgroundTransparency = 0.25
camlockBtn.Text = ""
camlockBtn.AutoButtonColor = false
camlockBtn.Visible = false
camlockBtn.Parent = screenHudGui
Instance.new("UICorner", camlockBtn).CornerRadius = UDim.new(0, 16)

camlockStroke = Instance.new("UIStroke", camlockBtn)
camlockStroke.Color = Color3.fromRGB(60, 60, 80)
camlockStroke.Thickness = 1.8

local camlockIcon = Instance.new("ImageLabel")
camlockIcon.Size = UDim2.new(0, 22, 0, 22)
camlockIcon.Position = UDim2.new(0.5, -11, 0, 8)
camlockIcon.BackgroundTransparency = 1
camlockIcon.Image = "rbxassetid://10734898355"
camlockIcon.ImageColor3 = Color3.fromRGB(180, 180, 200)
camlockIcon.Parent = camlockBtn

camlockStatusText = Instance.new("TextLabel")
camlockStatusText.Size = UDim2.new(1, 0, 0, 16)
camlockStatusText.Position = UDim2.new(0, 0, 0, 32)
camlockStatusText.BackgroundTransparency = 1
camlockStatusText.Text = "LOCK"
camlockStatusText.TextColor3 = Color3.fromRGB(150, 160, 180)
camlockStatusText.Font = Enum.Font.GothamBold
camlockStatusText.TextSize = 11
camlockStatusText.Parent = camlockBtn

updateCamlockButtonVisual = function(isLocked, targetPlayer)
    if isLocked then
        camlockStatusText.Text = targetPlayer and (targetPlayer.DisplayName:sub(1, 6) .. "..") or "LOCKED"
        camlockStatusText.TextColor3 = Color3.fromRGB(255, 60, 60)
        camlockIcon.ImageColor3 = Color3.fromRGB(255, 60, 60)
        camlockStroke.Color = Color3.fromRGB(255, 60, 60)
        TweenService:Create(camlockBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(42, 20, 24)}):Play()
    else
        camlockStatusText.Text = "LOCK"
        camlockStatusText.TextColor3 = Color3.fromRGB(150, 160, 180)
        camlockIcon.ImageColor3 = Color3.fromRGB(180, 180, 200)
        camlockStroke.Color = Color3.fromRGB(60, 60, 80)
        TweenService:Create(camlockBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(22, 22, 28)}):Play()
    end
end

local function getNearestPlayerToCamera()
    local myRoot = getRootPart()
    if not myRoot then return nil end

    local nearestTargetPart = nil
    local shortestDist = math.huge
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local targetChar = otherPlayer.Character
            local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
            local targetHead = targetChar:FindFirstChild("Head")

            if targetHum and targetHum.Health > 0 and targetHead then
                local worldDistance = (targetHead.Position - myRoot.Position).Magnitude
                if worldDistance <= CAMLOCK_MAX_DIST then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetHead.Position)
                    if onScreen then
                        local crosshairDistance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        local score = crosshairDistance + (worldDistance * 0.8)
                        if score < shortestDist then
                            shortestDist = score
                            nearestTargetPart = targetHead
                        end
                    end
                end
            end
        end
    end
    return nearestTargetPart
end

camlockBtn.Activated:Connect(function()
    if not isTargetLocked then
        local target = getNearestPlayerToCamera()
        if target then
            lockedTargetPart = target
            isTargetLocked = true
            local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
            updateCamlockButtonVisual(true, targetPlayer)
        else
            camlockStroke.Color = Color3.fromRGB(255, 160, 40)
            task.delay(0.25, function()
                if not isTargetLocked then
                    camlockStroke.Color = Color3.fromRGB(60, 60, 80)
                end
            end)
        end
    else
        isTargetLocked = false
        lockedTargetPart = nil
        updateCamlockButtonVisual(false)
    end

    camlockBtn.Size = UDim2.new(0, 52, 0, 52)
    TweenService:Create(camlockBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 56, 0, 56)
    }):Play()
end)

setCamlockButtonVisible = function(visible)
    if visible then
        camlockBtn.Visible = true
        TweenService:Create(camlockBtn, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -75, 0.52, 0)
        }):Play()
    else
        local tween = TweenService:Create(camlockBtn, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 30, 0.52, 0)
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not camlockEnabled then
                camlockBtn.Visible = false
                isTargetLocked = false
                lockedTargetPart = nil
                updateCamlockButtonVisual(false)
            end
        end)
    end
end

end -- [End HUD Block]

-- ====================================================================
-- 3D Part & SurfaceGui Setup
-- ====================================================================
do
    uiPart = Instance.new("Part")
uiPart.Name = "Spatial_UI_Anchor"
uiPart.Size = Vector3.new(currentPartWidth, currentPartHeight, 0.05)
uiPart.Anchored = true
uiPart.CanCollide = false
uiPart.Transparency = 1
uiPart.CastShadow = false
uiPart.Position = Vector3.new(0, 9999, 0)
uiPart.Parent = Workspace

surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "SpatialUI"
surfaceGui.Adornee = uiPart
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 100
surfaceGui.AlwaysOnTop = true
surfaceGui.Enabled = false
surfaceGui.Parent = targetGuiParent

container = Instance.new("CanvasGroup")
container.Name = "MainContainer"
container.Size = UDim2.new(1, 0, 1, 0)
container.BackgroundTransparency = 1
container.GroupTransparency = 1
container.Parent = surfaceGui

backSurfaceGui = Instance.new("SurfaceGui")
backSurfaceGui.Name = "SpatialUI_Backplate"
backSurfaceGui.Adornee = uiPart
backSurfaceGui.Face = Enum.NormalId.Back
backSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
backSurfaceGui.PixelsPerStud = 100
backSurfaceGui.AlwaysOnTop = false
backSurfaceGui.Enabled = false
backSurfaceGui.Parent = targetGuiParent

local backContainer = Instance.new("Frame")
backContainer.Name = "BackContainer"
backContainer.Size = UDim2.new(1, 0, 1, 0)
backContainer.BackgroundTransparency = 1
backContainer.Parent = backSurfaceGui

local backSidebar = Instance.new("Frame")
backSidebar.Name = "BackSidebar"
backSidebar.Size = UDim2.new(0, 52, 1, -55)
backSidebar.Position = UDim2.new(1, -52, 0, 0)
backSidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
backSidebar.BorderSizePixel = 0
backSidebar.Parent = backContainer
Instance.new("UICorner", backSidebar).CornerRadius = UDim.new(0, 16)

local backSidebarStroke = Instance.new("UIStroke", backSidebar)
backSidebarStroke.Color = Color3.fromRGB(55, 55, 70)
backSidebarStroke.Thickness = 1.5

local backMainWindow = Instance.new("Frame")
backMainWindow.Name = "BackMainWindow"
backMainWindow.Size = UDim2.new(1, -60, 1, -55)
backMainWindow.Position = UDim2.new(0, 0, 0, 0)
backMainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
backMainWindow.BorderSizePixel = 0
backMainWindow.Parent = backContainer
Instance.new("UICorner", backMainWindow).CornerRadius = UDim.new(0, 16)

local backMainStroke = Instance.new("UIStroke", backMainWindow)
backMainStroke.Color = Color3.fromRGB(65, 65, 80)
backMainStroke.Thickness = 1.5

-- Sidebar à¸”à¹‰à¸²à¸™à¸«à¸™à¹‰à¸²
sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 52, 1, -55)
sidebar.Position = UDim2.new(0, 0, 0, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
sidebar.BorderSizePixel = 0
sidebar.Parent = container
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 16)

local sidebarStroke = Instance.new("UIStroke", sidebar)
sidebarStroke.Color = Color3.fromRGB(55, 55, 70)
sidebarStroke.Thickness = 1.5

tabIndicator = Instance.new("Frame")
tabIndicator.Name = "TabIndicator"
tabIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
tabIndicator.Size = UDim2.new(0, 36, 0, 36)
tabIndicator.Position = UDim2.new(0.5, 0, 0, 30)
tabIndicator.BackgroundColor3 = Color3.fromRGB(50, 120, 240)
tabIndicator.BorderSizePixel = 0
tabIndicator.ZIndex = 1
tabIndicator.Parent = sidebar
Instance.new("UICorner", tabIndicator).CornerRadius = UDim.new(0, 8)

-- MainWindow à¸”à¹‰à¸²à¸™à¸«à¸™à¹‰à¸²
mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.new(1, -60, 1, -55)
mainFrame.Position = UDim2.new(0, 60, 0, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = container
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(65, 65, 80)
stroke.Thickness = 1.5

titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 0, 35)
titleLabel.Position = UDim2.new(0, 16, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Player Controls"
titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local titleThread = nil
local scrambleChars = {"-", "_", "/", "\\", ">", "<", "*", "!", "#", "$"}

typewriteTitle = function(targetText)
    if titleThread then task.cancel(titleThread) end
    titleThread = task.spawn(function()
        local current = ""
        for i = 1, #targetText do
            local nextChar = targetText:sub(i, i)
            for _ = 1, 2 do
                titleLabel.Text = current .. scrambleChars[math.random(1, #scrambleChars)]
                task.wait(0.012)
            end
            current = current .. nextChar
            titleLabel.Text = current
        end
        titleLabel.Text = targetText
    end)
end

closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -72, 0, 8)
minBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.Parent = mainFrame
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Pages Container (Continuous Track)
trackViewport = Instance.new("Frame")
trackViewport.Name = "TrackViewport"
trackViewport.Size = UDim2.new(1, 0, 1, -45)
trackViewport.Position = UDim2.new(0, 0, 0, 45)
trackViewport.BackgroundTransparency = 1
trackViewport.ClipsDescendants = true
trackViewport.Parent = mainFrame

pagesTrack = Instance.new("ScrollingFrame")
pagesTrack.Name = "PagesTrack"
pagesTrack.Size = UDim2.new(1, 0, 1, 0)
pagesTrack.Position = UDim2.new(0, 0, 0, 0)
pagesTrack.BackgroundTransparency = 1
pagesTrack.BorderSizePixel = 0
pagesTrack.ScrollBarThickness = 0
pagesTrack.ScrollingEnabled = false
pagesTrack.CanvasSize = UDim2.new(3, 0, 1, 0)
pagesTrack.Parent = trackViewport

local trackLayout = Instance.new("UIListLayout")
trackLayout.FillDirection = Enum.FillDirection.Horizontal
trackLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackLayout.Parent = pagesTrack

local function createPageColumn(order)
    local col = Instance.new("ScrollingFrame")
    col.Size = UDim2.new(0.33333, 0, 1, 0)
    col.BackgroundTransparency = 1
    col.BorderSizePixel = 0
    col.ScrollBarThickness = 3
    col.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    col.CanvasSize = UDim2.new(0, 0, 0, 0)
    col.AutomaticCanvasSize = Enum.AutomaticSize.Y
    col.LayoutOrder = order
    col.Parent = pagesTrack

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = col

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 14)
    padding.Parent = col

    return col
end

local playerPage = createPageColumn(1)
local visualsPage = createPageColumn(2)
local settingsPage = createPageColumn(3)

-- ====================================================================
-- Universal UI Component Builder
-- ====================================================================
local function createToggleRow(parent, name, defaultState, onToggle, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -32, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    row.LayoutOrder = order or 1
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 75, 0, 28)
    toggleBtn.Position = UDim2.new(1, -85, 0.5, -14)
    toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(45, 180, 100) or Color3.fromRGB(60, 60, 75)
    toggleBtn.Text = defaultState and "ON" or "OFF"
    toggleBtn.TextColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 13
    toggleBtn.Parent = row
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

    local isToggled = defaultState
    toggleBtn.Activated:Connect(function()
        if interactionState ~= "IDLE" then return end
        isToggled = not isToggled
        if isToggled then
            toggleBtn.Text = "ON"
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 180, 100), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        else
            toggleBtn.Text = "OFF"
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 75), TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
        end
        onToggle(isToggled)
    end)
    return row
end

local function createSliderRow(parent, name, minVal, maxVal, defaultVal, onSliderChange, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -32, 0, 65)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    row.LayoutOrder = order or 1
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 0, 25)
    label.Position = UDim2.new(0, 14, 0, 8)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0, 60, 0, 25)
    valLabel.Position = UDim2.new(1, -72, 0, 8)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(defaultVal)
    valLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 14
    valLabel.Parent = row

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -28, 0, 6)
    sliderBar.Position = UDim2.new(0, 14, 0, 42)
    sliderBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = row
    Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(1, 0)

    local initialPercent = (defaultVal - minVal) / (maxVal - minVal)
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

    local sliderKnob = Instance.new("TextButton")
    sliderKnob.Name = "Knob"
    sliderKnob.Size = UDim2.new(0, 20, 0, 20)
    sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    sliderKnob.Position = UDim2.new(initialPercent, 0, 0.5, 0)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
    sliderKnob.Text = ""
    sliderKnob.AutoButtonColor = false
    sliderKnob.Parent = sliderBar
    Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

    local isHoldingKnob = false
    local knobTouchId = nil

    local function setSliderValue(canvasX)
        local rel = math.clamp((canvasX - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(rel, 0, 1, 0)
        sliderKnob.Position = UDim2.new(rel, 0, 0.5, 0)
        local resultVal = math.floor(minVal + (maxVal - minVal) * rel)
        valLabel.Text = tostring(resultVal)
        onSliderChange(resultVal)
    end

    sliderKnob.InputBegan:Connect(function(input)
        if interactionState == "IDLE" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            interactionState = "SLIDING"
            isHoldingKnob = true
            knobTouchId = input
            TweenService:Create(sliderKnob, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(100, 200, 255)}):Play()
        end
    end)

    sliderKnob.InputChanged:Connect(function(input)
        if isHoldingKnob and (input == knobTouchId or input.UserInputType == Enum.UserInputType.MouseMovement) then
            setSliderValue(input.Position.X)
        end
    end)

    local function releaseKnob(input)
        if isHoldingKnob and (input == knobTouchId or input.UserInputType == Enum.UserInputType.MouseButton1) then
            isHoldingKnob = false
            knobTouchId = nil
            TweenService:Create(sliderKnob, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(240, 245, 255)}):Play()
            if interactionState == "SLIDING" then
                interactionState = "IDLE"
            end
        end
    end

    sliderKnob.InputEnded:Connect(releaseKnob)
    UserInputService.InputEnded:Connect(releaseKnob)
    return row
end

local function createActionButton(parent, name, btnText, onClick, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -32, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    row.LayoutOrder = order or 1
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local actionBtn = Instance.new("TextButton")
    actionBtn.Size = UDim2.new(0, 85, 0, 28)
    actionBtn.Position = UDim2.new(1, -95, 0.5, -14)
    actionBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 240)
    actionBtn.Text = btnText
    actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.TextSize = 12
    actionBtn.Parent = row
    Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)

    actionBtn.Activated:Connect(function()
        if interactionState ~= "IDLE" then return end
        onClick()
    end)
    return row
end

end -- [End 3D UI Block]

-- ====================================================================
-- ScreenGui à¸ªà¸³à¸«à¸£à¸±à¸šà¸›à¸¸à¹ˆà¸¡à¸„à¸§à¸šà¸„à¸¸à¸¡à¸šà¸´à¸™à¸šà¸™à¸¡à¸·à¸­à¸–à¸·à¸­
-- ====================================================================
do
    mobileGui = Instance.new("ScreenGui")
mobileGui.Name = "SpatialUI_MobileControls"
mobileGui.ResetOnSpawn = false
mobileGui.DisplayOrder = 998
mobileGui.Parent = targetGuiParent

mobileFlyFrame = Instance.new("Frame")
mobileFlyFrame.Name = "FlyButtons"
mobileFlyFrame.Size = UDim2.new(0, 55, 0, 120)
mobileFlyFrame.Position = UDim2.new(1, -75, 0.5, -60)
mobileFlyFrame.BackgroundTransparency = 1
mobileFlyFrame.Visible = false
mobileFlyFrame.Parent = mobileGui

local function createMobileFlyBtn(name, text, posY)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 50, 0, 50)
    btn.Position = UDim2.new(0, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    btn.BackgroundTransparency = 0.35
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 20
    btn.AutoButtonColor = false
    btn.Parent = mobileFlyFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke", btn)
    st.Color = Color3.fromRGB(80, 80, 100)
    st.Thickness = 1.5
    return btn
end

local btnFlyUp = createMobileFlyBtn("FlyUp", "â–²", 0)
local btnFlyDown = createMobileFlyBtn("FlyDown", "â–¼", 60)

btnFlyUp.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        mobileFlyUp = true
        btnFlyUp.BackgroundTransparency = 0.1
    end
end)
btnFlyUp.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        mobileFlyUp = false
        btnFlyUp.BackgroundTransparency = 0.35
    end
end)

btnFlyDown.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        mobileFlyDown = true
        btnFlyDown.BackgroundTransparency = 0.1
    end
end)
btnFlyDown.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        mobileFlyDown = false
        btnFlyDown.BackgroundTransparency = 0.35
    end
end)

end -- [End Mobile Controls Block]

-- ====================================================================
-- Universal Features Logic
-- ====================================================================
do
    startFly = function()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.PlatformStand = true
    flyAttachment = Instance.new("Attachment", root)
    flyVelocity = Instance.new("LinearVelocity")
    flyVelocity.Attachment0 = flyAttachment
    flyVelocity.MaxForce = math.huge
    flyVelocity.VectorVelocity = Vector3.zero
    flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVelocity.Parent = root

    flyAlign = Instance.new("AlignOrientation")
    flyAlign.Attachment0 = flyAttachment
    flyAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyAlign.MaxTorque = math.huge
    flyAlign.Responsiveness = 200
    flyAlign.Parent = root

    mobileFlyFrame.Visible = true
end

stopFly = function()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    if flyVelocity then flyVelocity:Destroy() end
    if flyAlign then flyAlign:Destroy() end
    if flyAttachment then flyAttachment:Destroy() end

    mobileFlyFrame.Visible = false
    mobileFlyUp = false
    mobileFlyDown = false
end

local espHighlights = {}
updateESP = function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            if espEnabled then
                if not espHighlights[p] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "ESP_Highlight"
                    hl.FillColor = Color3.fromRGB(255, 60, 60)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.Adornee = p.Character
                    hl.Parent = p.Character
                    espHighlights[p] = hl
                end
            else
                if espHighlights[p] then
                    espHighlights[p]:Destroy()
                    espHighlights[p] = nil
                end
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    if espHighlights[p] then
        espHighlights[p]:Destroy()
        espHighlights[p] = nil
    end
    if lockedTargetPart and lockedTargetPart.Parent == p.Character then
        isTargetLocked = false
        lockedTargetPart = nil
        updateCamlockButtonVisual(false)
    end
end)

local defaultAmbient = Lighting.Ambient
local defaultBrightness = Lighting.Brightness
local defaultClockTime = Lighting.ClockTime

applyFullbright = function(enable)
    if enable then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    else
        Lighting.Ambient = defaultAmbient
        Lighting.Brightness = defaultBrightness
        Lighting.ClockTime = defaultClockTime
    end
end

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

player.Idled:Connect(function()
    if antiAfkEnabled then
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.zero)
    end
end)

-- ====================================================================
-- Population of Menus
-- ====================================================================

-- [ TAB 1: PLAYER ]
createToggleRow(playerPage, "Walk Speed", false, function(v)
    speedEnabled = v
    local hum = getHumanoid()
    if hum and not v then hum.WalkSpeed = defaultSpeed end
end, 1)

createSliderRow(playerPage, "Speed Value", 16, 200, 16, function(v)
    currentSpeed = v
    if speedEnabled then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = currentSpeed end
    end
end, 2)

createToggleRow(playerPage, "Jump Power", false, function(v)
    jumpEnabled = v
    local hum = getHumanoid()
    if hum and not v then hum.UseJumpPower = true; hum.JumpPower = defaultJump end
end, 3)

createSliderRow(playerPage, "Jump Value", 50, 300, 50, function(v)
    currentJump = v
    if jumpEnabled then
        local hum = getHumanoid()
        if hum then hum.UseJumpPower = true; hum.JumpPower = currentJump end
    end
end, 4)

createToggleRow(playerPage, "Bunny Hop (Bhop)", false, function(v)
    bhopEnabled = v
    bhopMomentum = currentSpeed
    setBhopScreenWidgets(v)
end, 5)

createToggleRow(playerPage, "Fly Mode (Mobile/PC)", false, function(v)
    flyEnabled = v
    if v then startFly() else stopFly() end
end, 6)

createSliderRow(playerPage, "Fly Speed", 10, 200, 50, function(v)
    flySpeed = v
end, 7)

createToggleRow(playerPage, "Noclip (Walk Through)", false, function(v)
    noclipEnabled = v
end, 8)

createToggleRow(playerPage, "Infinite Jump", false, function(v)
    infJumpEnabled = v
end, 9)

-- [ TAB 2: VISUALS & COMBAT ]
createToggleRow(visualsPage, "Camlock (Nearest Player)", false, function(v)
    camlockEnabled = v
    if not v then
        isTargetLocked = false
        lockedTargetPart = nil
        updateCamlockButtonVisual(false)
    end
    setCamlockButtonVisible(v)
end, 1)

createToggleRow(visualsPage, "Player ESP (Chams)", false, function(v)
    espEnabled = v
    updateESP()
end, 2)

createToggleRow(visualsPage, "Fullbright", false, function(v)
    fullbrightEnabled = v
    applyFullbright(v)
end, 3)

-- [ TAB 3: SETTINGS & UTILITY ]
createToggleRow(settingsPage, "Anti-AFK (20m Kick Guard)", false, function(v)
    antiAfkEnabled = v
end, 1)

createActionButton(settingsPage, "Server Rejoin", "Rejoin", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
end, 2)

end -- [End Universal Features Block]

-- ====================================================================
-- Wardrobe & Character Look 3D UI Setup & Drag Handlers
-- ====================================================================
do
    wardrobePart = Instance.new("Part")
wardrobePart.Name = "Spatial_Wardrobe_Anchor"
wardrobePart.Size = Vector3.new(4.2, 3.6, 0.05)
wardrobePart.Anchored = true
wardrobePart.CanCollide = false
wardrobePart.Transparency = 1
wardrobePart.CastShadow = false
wardrobePart.Position = Vector3.new(0, 9999, 0)
wardrobePart.Parent = Workspace

wardrobeSurfaceGui = Instance.new("SurfaceGui")
wardrobeSurfaceGui.Name = "SpatialWardrobeUI"
wardrobeSurfaceGui.Adornee = wardrobePart
wardrobeSurfaceGui.Face = Enum.NormalId.Front
wardrobeSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
wardrobeSurfaceGui.PixelsPerStud = 100
wardrobeSurfaceGui.AlwaysOnTop = true
wardrobeSurfaceGui.Enabled = false
wardrobeSurfaceGui.Parent = targetGuiParent

wardrobeBackSurfaceGui = Instance.new("SurfaceGui")
wardrobeBackSurfaceGui.Name = "SpatialWardrobeUI_Backplate"
wardrobeBackSurfaceGui.Adornee = wardrobePart
wardrobeBackSurfaceGui.Face = Enum.NormalId.Back
wardrobeBackSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
wardrobeBackSurfaceGui.PixelsPerStud = 100
wardrobeBackSurfaceGui.AlwaysOnTop = false
wardrobeBackSurfaceGui.Enabled = false
wardrobeBackSurfaceGui.Parent = targetGuiParent

local wardrobeBackContainer = Instance.new("Frame")
wardrobeBackContainer.Name = "BackContainer"
wardrobeBackContainer.Size = UDim2.new(1, 0, 1, 0)
wardrobeBackContainer.BackgroundTransparency = 1
wardrobeBackContainer.Parent = wardrobeBackSurfaceGui

local wardrobeBackMainWindow = Instance.new("Frame")
wardrobeBackMainWindow.Name = "BackMainWindow"
wardrobeBackMainWindow.Size = UDim2.new(1, 0, 1, -55)
wardrobeBackMainWindow.Position = UDim2.new(0, 0, 0, 0)
wardrobeBackMainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
wardrobeBackMainWindow.BorderSizePixel = 0
wardrobeBackMainWindow.Parent = wardrobeBackContainer
Instance.new("UICorner", wardrobeBackMainWindow).CornerRadius = UDim.new(0, 16)
local wardrobeBackStroke = Instance.new("UIStroke", wardrobeBackMainWindow)
wardrobeBackStroke.Color = Color3.fromRGB(65, 65, 80)
wardrobeBackStroke.Thickness = 1.5

wardrobeContainer = Instance.new("CanvasGroup")
wardrobeContainer.Name = "WardrobeContainer"
wardrobeContainer.Size = UDim2.new(1, 0, 1, 0)
wardrobeContainer.BackgroundTransparency = 1
wardrobeContainer.GroupTransparency = 1
wardrobeContainer.Parent = wardrobeSurfaceGui

wardrobeMainWindow = Instance.new("Frame")
wardrobeMainWindow.Name = "MainWindow"
wardrobeMainWindow.Size = UDim2.new(1, 0, 1, -55)
wardrobeMainWindow.Position = UDim2.new(0, 0, 0, 0)
wardrobeMainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
wardrobeMainWindow.BorderSizePixel = 0
wardrobeMainWindow.ClipsDescendants = true
wardrobeMainWindow.Parent = wardrobeContainer
Instance.new("UICorner", wardrobeMainWindow).CornerRadius = UDim.new(0, 16)

local wardrobeStroke = Instance.new("UIStroke", wardrobeMainWindow)
wardrobeStroke.Color = Color3.fromRGB(65, 65, 80)
wardrobeStroke.Thickness = 1.5

local wardrobeTitle = Instance.new("TextLabel")
wardrobeTitle.Size = UDim2.new(1, -60, 0, 24)
wardrobeTitle.Position = UDim2.new(0, 16, 0, 8)
wardrobeTitle.BackgroundTransparency = 1
wardrobeTitle.Text = "Character Cosmetics"
wardrobeTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
wardrobeTitle.TextSize = 15
wardrobeTitle.Font = Enum.Font.GothamBold
wardrobeTitle.TextXAlignment = Enum.TextXAlignment.Left
wardrobeTitle.Parent = wardrobeMainWindow

local wardrobeSubTitle = Instance.new("TextLabel")
wardrobeSubTitle.Size = UDim2.new(1, -60, 0, 14)
wardrobeSubTitle.Position = UDim2.new(0, 16, 0, 29)
wardrobeSubTitle.BackgroundTransparency = 1
wardrobeSubTitle.Text = "@" .. player.DisplayName .. " // LOOK & VISUALS"
wardrobeSubTitle.TextColor3 = Color3.fromRGB(110, 125, 150)
wardrobeSubTitle.TextSize = 10
wardrobeSubTitle.Font = Enum.Font.GothamBold
wardrobeSubTitle.TextXAlignment = Enum.TextXAlignment.Left
wardrobeSubTitle.Parent = wardrobeMainWindow

wardrobeCloseBtn = Instance.new("TextButton")
wardrobeCloseBtn.Size = UDim2.new(0, 28, 0, 28)
wardrobeCloseBtn.Position = UDim2.new(1, -38, 0, 8)
wardrobeCloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
wardrobeCloseBtn.Text = "X"
wardrobeCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
wardrobeCloseBtn.Font = Enum.Font.GothamBold
wardrobeCloseBtn.TextSize = 14
wardrobeCloseBtn.Parent = wardrobeMainWindow
Instance.new("UICorner", wardrobeCloseBtn).CornerRadius = UDim.new(0, 6)

local wardrobePage = Instance.new("ScrollingFrame")
wardrobePage.Size = UDim2.new(1, 0, 1, -50)
wardrobePage.Position = UDim2.new(0, 0, 0, 50)
wardrobePage.BackgroundTransparency = 1
wardrobePage.BorderSizePixel = 0
wardrobePage.ScrollBarThickness = 3
wardrobePage.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
wardrobePage.CanvasSize = UDim2.new(0, 0, 0, 0)
wardrobePage.AutomaticCanvasSize = Enum.AutomaticSize.Y
wardrobePage.Parent = wardrobeMainWindow

local wardrobeLayout = Instance.new("UIListLayout")
wardrobeLayout.Padding = UDim.new(0, 10)
wardrobeLayout.SortOrder = Enum.SortOrder.LayoutOrder
wardrobeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
wardrobeLayout.Parent = wardrobePage

local wardrobePadding = Instance.new("UIPadding")
wardrobePadding.PaddingTop = UDim.new(0, 8)
wardrobePadding.PaddingBottom = UDim.new(0, 14)
wardrobePadding.Parent = wardrobePage

wardrobeGrabBarContainer = Instance.new("Frame")
wardrobeGrabBarContainer.Name = "WardrobeGrabBarArea"
wardrobeGrabBarContainer.Size = UDim2.new(1, 0, 0, 50)
wardrobeGrabBarContainer.Position = UDim2.new(0, 0, 1, -15)
wardrobeGrabBarContainer.BackgroundTransparency = 1
wardrobeGrabBarContainer.Parent = wardrobeContainer

wardrobeVisualBar = Instance.new("TextButton")
wardrobeVisualBar.Name = "WardrobeVisualBar"
wardrobeVisualBar.Size = UDim2.new(0.65, 0, 0, 14)
wardrobeVisualBar.Position = UDim2.new(0.175, 0, 0.5, -7)
wardrobeVisualBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
wardrobeVisualBar.BackgroundTransparency = 0.55
wardrobeVisualBar.Text = ""
wardrobeVisualBar.AutoButtonColor = false
wardrobeVisualBar.Parent = wardrobeGrabBarContainer
Instance.new("UICorner", wardrobeVisualBar).CornerRadius = UDim.new(1, 0)

local wardrobeBarStroke = Instance.new("UIStroke", wardrobeVisualBar)
wardrobeBarStroke.Color = Color3.fromRGB(200, 220, 255)
wardrobeBarStroke.Transparency = 0.6
wardrobeBarStroke.Thickness = 1.2

-- Character Cosmetic Features Logic
local freezeCharacter = false
local rainbowSkinEnabled = false
local ghostModeEnabled = false
local forcefieldEnabled = false
local neonGlowEnabled = false
local auraEnabled = false

local originalColors = {}
local originalMaterials = {}
local originalTransparencies = {}
local auraParticles = {}
local rainbowConnection = nil

local function cacheCharacterAppearance()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if not originalColors[part] then originalColors[part] = part.Color end
            if not originalMaterials[part] then originalMaterials[part] = part.Material end
            if not originalTransparencies[part] then originalTransparencies[part] = part.Transparency end
        end
    end
end

restoreCharacterAppearance = function()
    local char = player.Character
    if char then
        for part, col in pairs(originalColors) do
            if part and part.Parent then part.Color = col end
        end
        for part, mat in pairs(originalMaterials) do
            if part and part.Parent then part.Material = mat end
        end
        for part, tr in pairs(originalTransparencies) do
            if part and part.Parent then part.Transparency = tr end
        end
    end
    table.clear(originalColors)
    table.clear(originalMaterials)
    table.clear(originalTransparencies)

    for _, p in ipairs(auraParticles) do
        if p and p.Parent then p:Destroy() end
    end
    table.clear(auraParticles)

    if rainbowConnection then
        rainbowConnection:Disconnect()
        rainbowConnection = nil
    end
    rainbowSkinEnabled = false
    ghostModeEnabled = false
    forcefieldEnabled = false
    neonGlowEnabled = false
    auraEnabled = false

    local root = getRootPart()
    if root and freezeCharacter then
        freezeCharacter = false
        root.Anchored = false
    end
end

local function setFreezePose(enable)
    freezeCharacter = enable
    local root = getRootPart()
    if root then
        root.Anchored = enable
    end
end

local function setRainbowSkin(enable)
    rainbowSkinEnabled = enable
    if enable then
        cacheCharacterAppearance()
        if not rainbowConnection then
            rainbowConnection = RunService.Heartbeat:Connect(function()
                if not rainbowSkinEnabled then return end
                local char = player.Character
                if not char then return end
                local hue = (tick() % 4) / 4
                local color = Color3.fromHSV(hue, 0.85, 1)
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Color = color
                    end
                end
            end)
        end
    else
        if rainbowConnection then
            rainbowConnection:Disconnect()
            rainbowConnection = nil
        end
        local char = player.Character
        if char then
            for part, col in pairs(originalColors) do
                if part and part.Parent then part.Color = col end
            end
        end
    end
end

local function setGhostMode(enable)
    ghostModeEnabled = enable
    local char = player.Character
    if not char then return end
    if enable then
        cacheCharacterAppearance()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 0.6
            end
        end
    else
        for part, tr in pairs(originalTransparencies) do
            if part and part.Parent then part.Transparency = tr end
        end
    end
end

local function setForcefield(enable)
    forcefieldEnabled = enable
    local char = player.Character
    if not char then return end
    if enable then
        cacheCharacterAppearance()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Material = Enum.Material.Forcefield
            end
        end
    else
        for part, mat in pairs(originalMaterials) do
            if part and part.Parent then part.Material = mat end
        end
    end
end

local function setNeonGlow(enable)
    neonGlowEnabled = enable
    local char = player.Character
    if not char then return end
    if enable then
        cacheCharacterAppearance()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Material = Enum.Material.Neon
            end
        end
    else
        for part, mat in pairs(originalMaterials) do
            if part and part.Parent then part.Material = mat end
        end
    end
end

local function setAura(enable)
    auraEnabled = enable
    local root = getRootPart()
    if not root then return end
    if enable then
        local sparkles = Instance.new("Sparkles")
        sparkles.Name = "Wardrobe_Sparkles"
        sparkles.SparkleColor = Color3.fromRGB(80, 200, 255)
        sparkles.Parent = root
        table.insert(auraParticles, sparkles)

        local fire = Instance.new("Fire")
        fire.Name = "Wardrobe_Fire"
        fire.Color = Color3.fromRGB(120, 180, 255)
        fire.SecondaryColor = Color3.fromRGB(255, 100, 200)
        fire.Size = 4
        fire.Heat = 3
        fire.Parent = root
        table.insert(auraParticles, fire)
    else
        for _, p in ipairs(auraParticles) do
            if p and p.Parent then p:Destroy() end
        end
        table.clear(auraParticles)
    end
end

local function toggleAccessories()
    local char = player.Character
    if not char then return end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle then
                handle.Transparency = (handle.Transparency == 1) and 0 or 1
            end
        end
    end
end

-- Populate Wardrobe Options
createToggleRow(wardrobePage, "Freeze Pose (Mannequin)", false, function(v)
    setFreezePose(v)
end, 1)

createToggleRow(wardrobePage, "Rainbow Chroma Skin", false, function(v)
    setRainbowSkin(v)
end, 2)

createToggleRow(wardrobePage, "Ghost Mode (50% Alpha)", false, function(v)
    setGhostMode(v)
end, 3)

createToggleRow(wardrobePage, "Forcefield Shield", false, function(v)
    setForcefield(v)
end, 4)

createToggleRow(wardrobePage, "Neon Glow Body", false, function(v)
    setNeonGlow(v)
end, 5)

createToggleRow(wardrobePage, "Sparkles & Fire Aura", false, function(v)
    setAura(v)
end, 6)

createActionButton(wardrobePage, "Accessories (Hats)", "Toggle", function()
    toggleAccessories()
end, 7)

createActionButton(wardrobePage, "Reset Look & Effects", "Reset", function()
    restoreCharacterAppearance()
end, 8)

-- ====================================================================
-- Continuous Track Tab Animation Logic
-- ====================================================================
local allTabIcons = {}

local function switchTab(newIndex, targetCenterY, icon, tabName)
    if isAnimating or currentTabIndex == newIndex then return end
    isAnimating = true

    typewriteTitle(tabName)

    local currentCenterY = tabIndicator.Position.Y.Offset
    local dist = math.abs(targetCenterY - currentCenterY)
    local stretchAmount = math.clamp(dist * 0.28, 8, 20)

    TweenService:Create(tabIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 32, 0, 36 + stretchAmount)
    }):Play()

    TweenService:Create(tabIndicator, TweenInfo.new(0.42, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, targetCenterY)
    }):Play()

    task.delay(0.12, function()
        TweenService:Create(tabIndicator, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 36, 0, 36)
        }):Play()
    end)

    for _, otherIcon in ipairs(allTabIcons) do
        TweenService:Create(otherIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            ImageColor3 = Color3.fromRGB(150, 150, 170)
        }):Play()
    end
    TweenService:Create(icon, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        ImageColor3 = Color3.fromRGB(255, 255, 255)
    }):Play()

    local targetCanvasX = (newIndex - 1) * trackViewport.AbsoluteSize.X
    local trackTween = TweenService:Create(pagesTrack, TweenInfo.new(0.48, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
        CanvasPosition = Vector2.new(targetCanvasX, 0)
    })
    trackTween:Play()

    trackTween.Completed:Connect(function()
        currentTabIndex = newIndex
        isAnimating = false
    end)
end

local function createTabButton(iconId, index, titleText)
    local topY = 12 + ((index - 1) * 46)
    local centerY = topY + 18

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Size = UDim2.new(0, 36, 0, 36)
    btn.Position = UDim2.new(0.5, 0, 0, centerY)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 2
    btn.Parent = sidebar

    local icon = Instance.new("ImageLabel")
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = (index == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
    icon.ZIndex = 3
    icon.Parent = btn

    table.insert(allTabIcons, icon)

    btn.Activated:Connect(function()
        if interactionState ~= "IDLE" then return end
        switchTab(index, centerY, icon, titleText)
    end)

    return btn
end

createTabButton("rbxassetid://10723424505", 1, "Player Controls")
createTabButton("rbxassetid://10723415205", 2, "Visual Mod Menu")
createTabButton("rbxassetid://10734950309", 3, "Settings & Utility")

-- à¸›à¸¸à¹ˆà¸¡à¸£à¸¹à¸›à¹€à¸žà¸¥à¹€à¸¢à¸­à¸£à¹Œà¸—à¸µà¹ˆà¸¥à¹ˆà¸²à¸‡à¸ªà¸¸à¸”à¸‚à¸­à¸‡à¹à¸–à¸š Sidebar (Avatar Headshot)
profileBtn = Instance.new("TextButton")
profileBtn.Name = "PlayerAvatarBtn"
profileBtn.AnchorPoint = Vector2.new(0.5, 1)
profileBtn.Size = UDim2.new(0, 36, 0, 36)
profileBtn.Position = UDim2.new(0.5, 0, 1, -12)
profileBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
profileBtn.Text = ""
profileBtn.AutoButtonColor = false
profileBtn.ZIndex = 4
profileBtn.Parent = sidebar
Instance.new("UICorner", profileBtn).CornerRadius = UDim.new(1, 0)

profileStroke = Instance.new("UIStroke", profileBtn)
profileStroke.Color = Color3.fromRGB(65, 65, 85)
profileStroke.Thickness = 1.6

local profileImage = Instance.new("ImageLabel")
profileImage.Name = "AvatarHeadshot"
profileImage.Size = UDim2.new(1, -4, 1, -4)
profileImage.Position = UDim2.new(0, 2, 0, 2)
profileImage.BackgroundTransparency = 1
profileImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150"
profileImage.ZIndex = 5
profileImage.Parent = profileBtn
Instance.new("UICorner", profileImage).CornerRadius = UDim.new(1, 0)

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.Position = UDim2.new(1, -9, 1, -9)
statusDot.BackgroundColor3 = Color3.fromRGB(45, 215, 115)
statusDot.BorderSizePixel = 0
statusDot.ZIndex = 6
statusDot.Parent = profileBtn
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
local statusStroke = Instance.new("UIStroke", statusDot)
statusStroke.Color = Color3.fromRGB(16, 16, 22)
statusStroke.Thickness = 1.5

profileBtn.Activated:Connect(function()
    if interactionState ~= "IDLE" or isWardrobeAnimating then return end
    profileBtn.Size = UDim2.new(0, 32, 0, 32)
    TweenService:Create(profileBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 36, 0, 36)
    }):Play()

    if isWardrobeVisible then
        hideWardrobeWithAnimation()
    else
        summonWardrobeWithAnimation()
    end
end)

-- Resize Corner à¸”à¹‰à¸²à¸™à¸«à¸™à¹‰à¸²
resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "ResizeHandle"
resizeHandle.Size = UDim2.new(0, 44, 0, 44)
resizeHandle.Position = UDim2.new(1, -44, 1, -44)
resizeHandle.BackgroundTransparency = 1
resizeHandle.Text = ""
resizeHandle.AutoButtonColor = false
resizeHandle.Parent = mainFrame

local function createHandleLine(sizeX, posX, posY)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, sizeX, 0, 3)
    line.Position = UDim2.new(0, posX, 0, posY)
    line.BackgroundColor3 = Color3.fromRGB(160, 175, 205)
    line.BorderSizePixel = 0
    line.Rotation = -45
    line.Parent = resizeHandle
    Instance.new("UICorner", line).CornerRadius = UDim.new(1, 0)
    return line
end

local line1 = createHandleLine(16, 18, 24)
local line2 = createHandleLine(9, 25, 31)

-- Grab Bar Area à¸”à¹‰à¸²à¸™à¸¥à¹ˆà¸²à¸‡
grabBarContainer = Instance.new("Frame")
grabBarContainer.Name = "GrabBarArea"
grabBarContainer.Size = UDim2.new(1, 0, 0, 50)
grabBarContainer.Position = UDim2.new(0, 0, 1, -15)
grabBarContainer.BackgroundTransparency = 1
grabBarContainer.Parent = container

visualBar = Instance.new("TextButton")
visualBar.Name = "VisualBar"
visualBar.Size = UDim2.new(0.65, 0, 0, 14)
visualBar.Position = UDim2.new(0.175, 0, 0.5, -7)
visualBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
visualBar.BackgroundTransparency = 0.55
visualBar.Text = ""
visualBar.AutoButtonColor = false
visualBar.Parent = grabBarContainer
Instance.new("UICorner", visualBar).CornerRadius = UDim.new(1, 0)

local barStroke = Instance.new("UIStroke", visualBar)
barStroke.Color = Color3.fromRGB(200, 220, 255)
barStroke.Transparency = 0.6
barStroke.Thickness = 1.2

-- ====================================================================
-- 3. Drag / Resize Handlers
-- ====================================================================
local candidateInput = nil
local candidateType = nil
local touchStartPos = nil
local lastScreenPos = nil
local isConfirmedMoving = false
local DRAG_THRESHOLD = 12

local function moveUIByDelta(deltaX, deltaY)
    local root = getRootPart()
    local rightVec = root and root.CFrame.RightVector or camera.CFrame.RightVector
    local upVec = camera.CFrame.UpVector
    local distance = root and (uiPart.Position - root.Position).Magnitude or 5
    local studsPerPixel = (distance * 0.0035)

    local moveOffset = (rightVec * (deltaX * studsPerPixel)) - (upVec * (deltaY * studsPerPixel))
    local newPos = uiPart.Position + moveOffset

    uiPart.CFrame = getFacingCFrame(newPos)
end

local function moveWardrobeUIByDelta(deltaX, deltaY)
    local root = getRootPart()
    local rightVec = root and root.CFrame.RightVector or camera.CFrame.RightVector
    local upVec = camera.CFrame.UpVector
    local distance = root and (wardrobePart.Position - root.Position).Magnitude or 6
    local studsPerPixel = (distance * 0.0035)

    local moveOffset = (rightVec * (deltaX * studsPerPixel)) - (upVec * (deltaY * studsPerPixel))
    local newPos = wardrobePart.Position + moveOffset

    wardrobePart.CFrame = getFacingCFrame(newPos)
end

local function resizeUIByDelta(deltaX, deltaY)
    local root = getRootPart()
    local distance = root and (uiPart.Position - root.Position).Magnitude or 5
    local studsPerPixel = (distance * 0.0035)

    currentPartWidth = math.clamp(currentPartWidth + (deltaX * studsPerPixel), 3.4, 9.5)
    currentPartHeight = math.clamp(currentPartHeight + (deltaY * studsPerPixel), 2.2, 8.0)
    uiPart.Size = Vector3.new(currentPartWidth, currentPartHeight, 0.05)
    pagesTrack.CanvasPosition = Vector2.new((currentTabIndex - 1) * trackViewport.AbsoluteSize.X, 0)
end

visualBar.InputBegan:Connect(function(input)
    if interactionState ~= "IDLE" then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        candidateInput = input
        candidateType = "DRAG"
        touchStartPos = UserInputService:GetMouseLocation()
        lastScreenPos = touchStartPos
        isConfirmedMoving = false
    end
end)

wardrobeVisualBar.InputBegan:Connect(function(input)
    if interactionState ~= "IDLE" then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        candidateInput = input
        candidateType = "DRAG_WARDROBE"
        touchStartPos = UserInputService:GetMouseLocation()
        lastScreenPos = touchStartPos
        isConfirmedMoving = false
    end
end)

resizeHandle.InputBegan:Connect(function(input)
    if interactionState ~= "IDLE" then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        candidateInput = input
        candidateType = "RESIZE"
        touchStartPos = UserInputService:GetMouseLocation()
        lastScreenPos = touchStartPos
        isConfirmedMoving = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if candidateInput and (input == candidateInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local currentScreenPos = UserInputService:GetMouseLocation()
        if not isConfirmedMoving then
            local dist = (currentScreenPos - touchStartPos).Magnitude
            if dist >= DRAG_THRESHOLD then
                isConfirmedMoving = true
                if candidateType == "DRAG" then
                    interactionState = "DRAGGING"
                    TweenService:Create(visualBar, TweenInfo.new(0.2), {BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(150, 210, 255)}):Play()
                elseif candidateType == "DRAG_WARDROBE" then
                    interactionState = "DRAGGING_WARDROBE"
                    TweenService:Create(wardrobeVisualBar, TweenInfo.new(0.2), {BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(150, 210, 255)}):Play()
                elseif candidateType == "RESIZE" then
                    interactionState = "RESIZING"
                    TweenService:Create(line1, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 200, 255)}):Play()
                    TweenService:Create(line2, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 200, 255)}):Play()
                end
                lastScreenPos = currentScreenPos
            end
        else
            local delta = currentScreenPos - lastScreenPos
            if delta.Magnitude > 0 then
                if interactionState == "DRAGGING" then
                    moveUIByDelta(delta.X, delta.Y)
                elseif interactionState == "DRAGGING_WARDROBE" then
                    moveWardrobeUIByDelta(delta.X, delta.Y)
                elseif interactionState == "RESIZING" then
                    resizeUIByDelta(delta.X, delta.Y)
                end
            end
            lastScreenPos = currentScreenPos
        end
    end
end)

local function endDragOrResize(input)
    if candidateInput and (input == candidateInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        candidateInput = nil
        candidateType = nil
        touchStartPos = nil
        lastScreenPos = nil
        isConfirmedMoving = false

        if interactionState == "DRAGGING" or interactionState == "DRAGGING_WARDROBE" or interactionState == "RESIZING" then
            interactionState = "IDLE"
            TweenService:Create(visualBar, TweenInfo.new(0.2), {BackgroundTransparency = 0.55, BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            TweenService:Create(wardrobeVisualBar, TweenInfo.new(0.2), {BackgroundTransparency = 0.55, BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            TweenService:Create(line1, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(160, 175, 205)}):Play()
            TweenService:Create(line2, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(160, 175, 205)}):Play()
        end
    end
end

UserInputService.InputEnded:Connect(endDragOrResize)
end -- [End Wardrobe & Drag Handlers Block]

-- ====================================================================
-- Camera Alignment Zoom
-- ====================================================================
do
    performZoomInAndAlign = function()
    local isFirstPerson = isCurrentlyFirstPerson()
    if isFirstPerson then
        wasAlreadyFirstPerson = true
        return
    end

    wasAlreadyFirstPerson = false
    local root = getRootPart()
    local actualDist = (camera.CFrame.Position - (root and root.Position or camera.CFrame.Position)).Magnitude
    savedZoomDistance = math.clamp(actualDist, 4.0, 32.0)

    if root then
        local alignDuration = 0.28
        local startTick = tick()
        local initialCFrame = camera.CFrame

        while (tick() - startTick < alignDuration) do
            local alpha = math.clamp((tick() - startTick) / alignDuration, 0, 1)
            local smoothAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            local currentCamPos = camera.CFrame.Position
            local targetLookAt = currentCamPos + (root.CFrame.LookVector * 10)
            local goalRotCFrame = CFrame.lookAt(currentCamPos, targetLookAt)

            camera.CFrame = initialCFrame.Rotation:Lerp(goalRotCFrame.Rotation, smoothAlpha) + currentCamPos
            RunService.RenderStepped:Wait()
        end

        local finalCamPos = camera.CFrame.Position
        camera.CFrame = CFrame.lookAt(finalCamPos, finalCamPos + (root.CFrame.LookVector * 10))
    end

    local zoomDuration = 0.32
    local zoomValue = Instance.new("NumberValue")
    zoomValue.Value = savedZoomDistance

    local zoomTween = TweenService:Create(zoomValue, TweenInfo.new(zoomDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Value = 0.5
    })

    local connection = zoomValue.Changed:Connect(function(val)
        player.CameraMinZoomDistance = val
        player.CameraMaxZoomDistance = val
    end)

    zoomTween:Play()
    zoomTween.Completed:Wait()

    connection:Disconnect()
    zoomValue:Destroy()
end

performZoomOut = function()
    if wasAlreadyFirstPerson or not savedZoomDistance then return end

    local DURATION = 0.4
    local zoomValue = Instance.new("NumberValue")
    zoomValue.Value = 0.5

    local zoomTween = TweenService:Create(zoomValue, TweenInfo.new(DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Value = savedZoomDistance
    })

    local connection = zoomValue.Changed:Connect(function(val)
        player.CameraMinZoomDistance = val
        player.CameraMaxZoomDistance = val
    end)

    zoomTween:Play()
    zoomTween.Completed:Wait()
    connection:Disconnect()
    zoomValue:Destroy()

    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 128
end
end -- [End Camera Alignment Zoom Block]

-- ====================================================================
-- Hide & Summon Animations
-- ====================================================================
hideUIWithAnimation = function()
    if not isUIVisible or isAnimating then return end
    isAnimating = true

    if isWardrobeVisible then
        hideWardrobeWithAnimation()
    end

    backSurfaceGui.Enabled = false

    TweenService:Create(grabBarContainer, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 0, 1, -15) }):Play()
    TweenService:Create(sidebar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, -60, 0, 0) }):Play()
    TweenService:Create(mainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0.05, 0), Position = UDim2.new(0.45, 0, 0.45, 0) }):Play()

    local pushbackTarget = CFrame.new(uiPart.Position + (camera.CFrame.LookVector * 1.5) + Vector3.new(0, 0.35, 0)) * (uiPart.CFrame - uiPart.Position)

    local partTween = TweenService:Create(uiPart, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.3, 0.3, 0.05), CFrame = pushbackTarget })
    local fadeTween = TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })

    partTween:Play()
    fadeTween:Play()
    fadeTween.Completed:Wait()

    surfaceGui.Enabled = false
    uiPart.Position = Vector3.new(0, 9999, 0)
    isUIVisible = false
    updateToggleBtnState(false)

    performZoomOut()
    isAnimating = false
end

summonUIWithAnimation = function()
    if isUIVisible or isAnimating then return end
    isAnimating = true

    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not root then 
        isAnimating = false
        return 
    end

    performZoomInAndAlign()

    local finalSpawnPos = calculateCameraFrontPosition()
    local finalCFrame = getFacingCFrame(finalSpawnPos)

    uiPart.Size = Vector3.new(0.2, 0.2, 0.05)
    uiPart.CFrame = finalCFrame * CFrame.new(0, -0.8, -0.6) * CFrame.Angles(math.rad(12), 0, 0)

    container.GroupTransparency = 1
    sidebar.Position = UDim2.new(0, -60, 0, 0)
    mainFrame.Size = UDim2.new(0.15, 0, 0.1, 0)
    mainFrame.Position = UDim2.new(0.42, 0, 0.45, 0)
    grabBarContainer.Position = UDim2.new(0, 0, 1, -15)

    local targetCanvasX = (currentTabIndex - 1) * trackViewport.AbsoluteSize.X
    pagesTrack.CanvasPosition = Vector2.new(targetCanvasX, 0)

    surfaceGui.Enabled = true
    backSurfaceGui.Enabled = true
    isUIVisible = true
    updateToggleBtnState(true)

    local tabTitles = {
        [1] = "Player Controls",
        [2] = "Visual Mod Menu",
        [3] = "Settings & Utility"
    }
    typewriteTitle(tabTitles[currentTabIndex] or "Player Controls")

    local partTween = TweenService:Create(uiPart, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(currentPartWidth, currentPartHeight, 0.05),
        CFrame = finalCFrame
    })
    local containerFade = TweenService:Create(container, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        GroupTransparency = 0
    })

    partTween:Play()
    containerFade:Play()

    task.delay(0.12, function()
        TweenService:Create(mainFrame, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -60, 1, -55),
            Position = UDim2.new(0, 60, 0, 0)
        }):Play()
    end)

    task.delay(0.22, function()
        TweenService:Create(sidebar, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
    end)

    task.delay(0.32, function()
        local barTween = TweenService:Create(grabBarContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 1, -50)
        })
        barTween:Play()
        barTween.Completed:Connect(function()
            isAnimating = false
        end)
    end)
end

minBtn.Activated:Connect(function()
    hideUIWithAnimation()
end)

-- ====================================================================
-- Wardrobe Cinematic Cutscene & Custom Scriptable Camera System
-- ====================================================================
local wasMainUIVisibleBeforeWardrobe = false
local previousCameraType = nil
local previousCameraCFrame = nil

local orbitYaw = 0
local orbitPitch = 0
local orbitRadius = 6.8
local orbitLateralOffset = 1.35
local isOrbitDragging = false
local lastDragInputPos = nil

cleanupOrbitController = function()
    if orbitConn then
        orbitConn:Disconnect()
        orbitConn = nil
    end
    if orbitInputBeganConn then
        orbitInputBeganConn:Disconnect()
        orbitInputBeganConn = nil
    end
    if orbitInputEndedConn then
        orbitInputEndedConn:Disconnect()
        orbitInputEndedConn = nil
    end
    if orbitInputChangedConn then
        orbitInputChangedConn:Disconnect()
        orbitInputChangedConn = nil
    end
    isOrbitDragging = false
    lastDragInputPos = nil
end

setupOrbitController = function(charFocus, baseYaw)
    cleanupOrbitController()
    orbitYaw = baseYaw
    orbitPitch = 4
    orbitRadius = 6.8
    orbitLateralOffset = 1.35

    orbitInputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            isOrbitDragging = true
            lastDragInputPos = input.Position
        end
    end)

    orbitInputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            isOrbitDragging = false
            lastDragInputPos = nil
        end
    end)

    orbitInputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if isOrbitDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if lastDragInputPos then
                local delta = input.Position - lastDragInputPos
                orbitYaw = orbitYaw - (delta.X * 0.007)
                orbitPitch = math.clamp(orbitPitch - (delta.Y * 0.4), -55, 65)
            end
            lastDragInputPos = input.Position
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
            orbitRadius = math.clamp(orbitRadius - (input.Position.Z * 0.8), 3.0, 11.5)
        end
    end)

    orbitConn = RunService.RenderStepped:Connect(function(dt)
        if not isWardrobeMode or camera.CameraType ~= Enum.CameraType.Scriptable then return end
        local rotCF = CFrame.Angles(0, orbitYaw, 0) * CFrame.Angles(math.rad(orbitPitch), 0, 0)
        local camPos = charFocus + rotCF:VectorToWorldSpace(Vector3.new(orbitLateralOffset, 0, orbitRadius))
        local lookTarget = charFocus - rotCF:VectorToWorldSpace(Vector3.new(orbitLateralOffset * 0.35, 0, 0))
        camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camPos, lookTarget), 0.25)
    end)
end

summonWardrobeWithAnimation = function()
    if isWardrobeVisible or isWardrobeAnimating then return end
    isWardrobeAnimating = true
    isWardrobeMode = true

    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 10)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        isWardrobeAnimating = false
        isWardrobeMode = false
        return
    end

    -- 1. à¸‹à¹ˆà¸­à¸™ UI à¸«à¸¥à¸±à¸à¹„à¸›à¹€à¸¥à¸¢à¸ˆà¸™à¸à¸§à¹ˆà¸²à¸ˆà¸°à¸à¸”à¸›à¸´à¸”à¸•à¸¹à¹‰à¹à¸•à¹ˆà¸‡à¸•à¸±à¸§
    wasMainUIVisibleBeforeWardrobe = isUIVisible
    if isUIVisible then
        surfaceGui.Enabled = false
        backSurfaceGui.Enabled = false
        uiPart.Position = Vector3.new(0, 9999, 0)
        isUIVisible = false
        if updateToggleBtnState then updateToggleBtnState(false) end
    end

    -- 2. à¸¢à¸¶à¸”à¸•à¸³à¹à¸«à¸™à¹ˆà¸‡à¸•à¸±à¸§à¸¥à¸°à¸„à¸£à¸™à¸´à¹ˆà¸‡à¹† à¹€à¸žà¸·à¹ˆà¸­à¹„à¸¡à¹ˆà¹ƒà¸«à¹‰à¸¥à¸·à¹ˆà¸™à¹„à¸–à¸¥
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = true

    -- 3. à¸ªà¸¥à¸±à¸šà¸¡à¸²à¹ƒà¸Šà¹‰à¸à¸¥à¹‰à¸­à¸‡ Scriptable (à¸—à¸³à¹€à¸­à¸‡ 100% à¸ªà¸¡à¸¹à¸— à¹„à¸£à¹‰à¸à¸²à¸£à¸ªà¸±à¹ˆà¸™/à¸à¸£à¸°à¸•à¸¸à¸à¸ˆà¸²à¸ CameraModule à¸‚à¸­à¸‡à¹€à¸à¸¡)
    previousCameraType = camera.CameraType
    previousCameraCFrame = camera.CFrame
    camera.CameraType = Enum.CameraType.Scriptable

    -- 4. à¸„à¸³à¸™à¸§à¸“à¸•à¸³à¹à¸«à¸™à¹ˆà¸‡à¸à¸¥à¹‰à¸­à¸‡à¸—à¸µà¹ˆà¸«à¸±à¸™à¸›à¸£à¸°à¸ˆà¸±à¸™à¸«à¸™à¹‰à¸²à¸à¸±à¸šà¸•à¸±à¸§à¸¥à¸°à¸„à¸£ (à¸¡à¸­à¸‡à¸«à¸™à¹‰à¸²à¸•à¸±à¸§à¸¥à¸°à¸„à¸£à¹€à¸£à¸²)
    local charPos = root.Position
    local charLook = root.CFrame.LookVector
    local charRight = root.CFrame.RightVector
    local charFocus = charPos + Vector3.new(0, 0.6, 0)

    local camDist = 6.8
    local camHeight = 0.45
    local camLateral = 1.35 -- à¹€à¸šà¸µà¹ˆà¸¢à¸‡à¸à¸¥à¹‰à¸­à¸‡à¹„à¸›à¸—à¸²à¸‡à¸‚à¸§à¸²à¸‚à¸­à¸‡à¸•à¸±à¸§à¸¥à¸°à¸„à¸£à¹€à¸¥à¹‡à¸à¸™à¹‰à¸­à¸¢ à¹€à¸žà¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¸•à¸±à¸§à¸¥à¸°à¸„à¸£à¸­à¸¢à¸¹à¹ˆà¸‚à¸§à¸²à¸ˆà¸­ à¹à¸¥à¸°à¸¡à¸µà¸—à¸µà¹ˆà¸§à¹ˆà¸²à¸‡à¸‹à¹‰à¸²à¸¢à¸ˆà¸­à¸ªà¸³à¸«à¸£à¸±à¸š UI

    local goalCamPos = charFocus + (charLook * camDist) + (charRight * camLateral) + Vector3.new(0, camHeight, 0)
    local goalLookAt = charFocus - (charRight * 0.35)
    local goalCamCFrame = CFrame.lookAt(goalCamPos, goalLookAt)

    -- 5. à¸„à¸±à¸•à¸‹à¸µà¸™à¸à¸¥à¹‰à¸­à¸‡à¹€à¸¥à¸·à¹ˆà¸­à¸™à¹€à¸‚à¹‰à¸²à¸¡à¸²à¸›à¸£à¸°à¸ˆà¸±à¸™à¸«à¸™à¹‰à¸²à¸•à¸±à¸§à¸¥à¸°à¸„à¸£à¸­à¸¢à¹ˆà¸²à¸‡à¸ªà¸¡à¸¹à¸— (Cinematic Camera Glide)
    local startCamCFrame = camera.CFrame
    local enterDuration = 0.52
    local startTick = tick()

    while (tick() - startTick < enterDuration) do
        local alpha = math.clamp((tick() - startTick) / enterDuration, 0, 1)
        local smoothAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        camera.CFrame = startCamCFrame:Lerp(goalCamCFrame, smoothAlpha)
        RunService.RenderStepped:Wait()
    end
    camera.CFrame = goalCamCFrame

    -- 6. à¸§à¸²à¸‡à¸•à¸³à¹à¸«à¸™à¹ˆà¸‡à¸«à¸™à¹‰à¸² 3D UI à¸•à¸¹à¹‰à¹à¸•à¹ˆà¸‡à¸•à¸±à¸§à¸—à¸²à¸‡à¸à¸±à¹ˆà¸‡à¸‹à¹‰à¸²à¸¢à¸‚à¸­à¸‡à¸ˆà¸­ à¹ƒà¸«à¹‰à¸«à¸±à¸™à¸•à¸£à¸‡à¹€à¸‚à¹‰à¸²à¸«à¸²à¸à¸¥à¹‰à¸­à¸‡à¸­à¸¢à¹ˆà¸²à¸‡à¸ªà¸¡à¸šà¸¹à¸£à¸“à¹Œà¹à¸šà¸š
    local curCamCF = camera.CFrame
    local uiDist = 4.6
    local uiLeft = 2.25
    local uiElev = 0.05

    local wardrobeSpawnPos = curCamCF.Position + (curCamCF.LookVector * uiDist) - (curCamCF.RightVector * uiLeft) + (curCamCF.UpVector * uiElev)
    local finalCFrame = CFrame.lookAt(wardrobeSpawnPos, wardrobeSpawnPos + curCamCF.LookVector)

    wardrobePart.Size = Vector3.new(0.2, 0.2, 0.05)
    wardrobePart.CFrame = finalCFrame * CFrame.new(0, -0.6, -0.4)
    wardrobeContainer.GroupTransparency = 1
    wardrobeMainWindow.Size = UDim2.new(0.15, 0, 0.1, 0)
    wardrobeMainWindow.Position = UDim2.new(0.42, 0, 0.45, 0)
    wardrobeGrabBarContainer.Position = UDim2.new(0, 0, 1, -15)

    wardrobeSurfaceGui.AlwaysOnTop = true
    wardrobeSurfaceGui.Enabled = true
    wardrobeBackSurfaceGui.Enabled = true
    isWardrobeVisible = true

    profileStroke.Color = Color3.fromRGB(50, 140, 255)
    TweenService:Create(profileBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(35, 45, 65)}):Play()

    local partTween = TweenService:Create(wardrobePart, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(4.2, 3.6, 0.05),
        CFrame = finalCFrame
    })
    local containerFade = TweenService:Create(wardrobeContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        GroupTransparency = 0
    })

    partTween:Play()
    containerFade:Play()

    task.delay(0.1, function()
        TweenService:Create(wardrobeMainWindow, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, -55),
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
    end)

    task.delay(0.25, function()
        local barTween = TweenService:Create(wardrobeGrabBarContainer, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 1, -50)
        })
        barTween:Play()
        barTween.Completed:Connect(function()
            isWardrobeAnimating = false
        end)
    end)

    -- 7. à¹€à¸£à¸´à¹ˆà¸¡à¸£à¸°à¸šà¸šà¸à¸¥à¹‰à¸­à¸‡à¸•à¸£à¸§à¸ˆà¸”à¸¹à¸•à¸±à¸§à¸¥à¸°à¸„à¸£ 360 à¸­à¸‡à¸¨à¸² (à¸¥à¸²à¸à¹€à¸¡à¸²à¸ªà¹Œà¸«à¸¡à¸¸à¸™à¸£à¸­à¸šà¸•à¸±à¸§ + à¸‹à¸¹à¸¡à¹€à¸‚à¹‰à¸²à¸­à¸­à¸à¹„à¸”à¹‰)
    local baseYaw = math.atan2(charLook.X, charLook.Z)
    setupOrbitController(charFocus, baseYaw)
end

hideWardrobeWithAnimation = function()
    if not isWardrobeVisible or isWardrobeAnimating then return end
    isWardrobeAnimating = true

    -- à¸›à¸´à¸”à¸•à¸±à¸§à¸„à¸§à¸šà¸„à¸¸à¸¡à¸«à¸¡à¸¸à¸™à¸à¸¥à¹‰à¸­à¸‡
    cleanupOrbitController()

    wardrobeBackSurfaceGui.Enabled = false
    profileStroke.Color = Color3.fromRGB(65, 65, 85)
    TweenService:Create(profileBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(24, 24, 32)}):Play()

    TweenService:Create(wardrobeGrabBarContainer, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 0, 1, -15) }):Play()
    TweenService:Create(wardrobeMainWindow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0.05, 0), Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()

    local pushbackTarget = CFrame.new(wardrobePart.Position + (camera.CFrame.LookVector * 1.5) + Vector3.new(0, 0.35, 0)) * (wardrobePart.CFrame - wardrobePart.Position)
    local partTween = TweenService:Create(wardrobePart, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.3, 0.3, 0.05), CFrame = pushbackTarget })
    local fadeTween = TweenService:Create(wardrobeContainer, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })

    partTween:Play()
    fadeTween:Play()
    fadeTween.Completed:Wait()

    wardrobeSurfaceGui.Enabled = false
    wardrobePart.Position = Vector3.new(0, 9999, 0)
    isWardrobeVisible = false

    -- à¸„à¸±à¸•à¸‹à¸µà¸™à¸à¸¥à¹‰à¸­à¸‡à¹€à¸¥à¸·à¹ˆà¸­à¸™à¸à¸¥à¸±à¸šà¹„à¸›à¸¢à¸±à¸‡à¸¡à¸¸à¸¡à¸¡à¸­à¸‡à¹€à¸”à¸´à¸¡à¸‚à¸­à¸‡à¸œà¸¹à¹‰à¹€à¸¥à¹ˆà¸™
    local root = getRootPart()
    local returnDuration = 0.44
    local startCam = camera.CFrame
    local goalCam = previousCameraCFrame or (root and CFrame.lookAt(root.Position - (root.CFrame.LookVector * 6.5) + Vector3.new(0, 1.8, 0), root.Position + Vector3.new(0, 0.8, 0)) or startCam)

    local startTick = tick()
    while (tick() - startTick < returnDuration) do
        local alpha = math.clamp((tick() - startTick) / returnDuration, 0, 1)
        local smoothAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        camera.CFrame = startCam:Lerp(goalCam, smoothAlpha)
        RunService.RenderStepped:Wait()
    end
    camera.CFrame = goalCam

    -- à¸„à¸·à¸™à¸„à¹ˆà¸²à¸›à¸£à¸°à¹€à¸ à¸—à¸à¸¥à¹‰à¸­à¸‡à¹€à¸”à¸´à¸¡ à¹à¸¥à¸°à¸›à¸¥à¸”à¸¥à¹‡à¸­à¸„à¸•à¸±à¸§à¸¥à¸°à¸„à¸£
    camera.CameraType = previousCameraType or Enum.CameraType.Custom
    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 128
    if not freezeCharacter and root then
        root.Anchored = false
    end
    isWardrobeMode = false

    -- à¸à¸¹à¹‰à¸„à¸·à¸™ UI à¸«à¸¥à¸±à¸à¸à¸¥à¸±à¸šà¸¡à¸²à¸–à¹‰à¸²à¸à¹ˆà¸­à¸™à¸«à¸™à¹‰à¸²à¸™à¸µà¹‰à¹€à¸›à¸´à¸”à¸­à¸¢à¸¹à¹ˆ
    if wasMainUIVisibleBeforeWardrobe then
        wasMainUIVisibleBeforeWardrobe = false
        summonUIWithAnimation()
    end

    isWardrobeAnimating = false
end

wardrobeCloseBtn.Activated:Connect(function()
    hideWardrobeWithAnimation()
end)

-- ====================================================================
-- ScreenGui Trigger Controls (Floating Toggle Pill + Hotkeys + Triple-Tap)
-- ====================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpatialUI_SecretOpener"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = targetGuiParent

-- 1. Floating Toggle Button (Visible Pill with Dragging support)
local toggleMenuBtn = Instance.new("TextButton")
toggleMenuBtn.Name = "FloatingMenuToggle"
toggleMenuBtn.Size = UDim2.new(0, 115, 0, 36)
toggleMenuBtn.Position = UDim2.new(0, 16, 0.45, 0)
toggleMenuBtn.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
toggleMenuBtn.BackgroundTransparency = 0.2
toggleMenuBtn.Text = "âœ¦ 3D MENU"
toggleMenuBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
toggleMenuBtn.TextSize = 13
toggleMenuBtn.Font = Enum.Font.GothamBold
toggleMenuBtn.AutoButtonColor = false
toggleMenuBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 18)
toggleCorner.Parent = toggleMenuBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Thickness = 1.5
toggleStroke.Color = Color3.fromRGB(0, 170, 255)
toggleStroke.Transparency = 0.3
toggleStroke.Parent = toggleMenuBtn

updateToggleBtnState = function(open)
    if not toggleMenuBtn or not toggleStroke then return end
    if open then
        toggleMenuBtn.Text = "âœ• CLOSE 3D"
        toggleStroke.Color = Color3.fromRGB(255, 90, 90)
    else
        toggleMenuBtn.Text = "âœ¦ 3D MENU"
        toggleStroke.Color = Color3.fromRGB(0, 170, 255)
    end
end

-- Draggable implementation for Floating Toggle Button
do
    local dragging = false
    local dragInput, dragStart, startPos

    toggleMenuBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = toggleMenuBtn.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    toggleMenuBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            toggleMenuBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

toggleMenuBtn.Activated:Connect(function()
    if isWardrobeVisible then return end
    if isUIVisible then
        hideUIWithAnimation()
    else
        summonUIWithAnimation()
    end
end)

-- 2. Secret Triple-Tap Trigger (on Roblox Logo)
local secretButton = Instance.new("TextButton")
secretButton.Name = "RobloxLogo_SecretTrigger"
secretButton.Size = UDim2.new(0, 50, 0, 50)
secretButton.Position = UDim2.new(0, 5, 0, 5)
secretButton.BackgroundTransparency = 1
secretButton.Text = ""
secretButton.Parent = screenGui

local tapCount = 0
local lastTapTime = 0
local TRIPLE_TAP_DELAY = 1.0

secretButton.Activated:Connect(function()
    local now = tick()
    if now - lastTapTime > TRIPLE_TAP_DELAY then
        tapCount = 1
    else
        tapCount = tapCount + 1
    end
    lastTapTime = now

    if tapCount >= 3 then
        tapCount = 0
        if isWardrobeVisible then return end
        if isUIVisible then
            hideUIWithAnimation()
        else
            summonUIWithAnimation()
        end
    end
end)

-- 3. Keyboard Hotkeys (RightShift, Insert, K)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.K then
        if isWardrobeVisible then return end
        if isUIVisible then
            hideUIWithAnimation()
        else
            summonUIWithAnimation()
        end
    end
end)

-- ====================================================================
-- 1. Main RenderStepped Loop (Bhop & Speedometer)
-- ====================================================================
local loopConnection = RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    -- 1. WalkSpeed / JumpPower Lock
    if hum then
        if speedEnabled and hum.WalkSpeed ~= currentSpeed then
            hum.WalkSpeed = currentSpeed
        end
        if jumpEnabled then
            hum.UseJumpPower = true
            if hum.JumpPower ~= currentJump then
                hum.JumpPower = currentJump
            end
        end
    end

    -- 2. Bhop System
    if bhopEnabled and hum and root and not flyEnabled then
        local moveDir = hum.MoveDirection
        local isMoving = moveDir.Magnitude > 0.05
        local isGrounded = hum.FloorMaterial ~= Enum.Material.Air
        local currentVel = root.AssemblyLinearVelocity
        local actualHorizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z).Magnitude
        local baseGroundSpeed = speedEnabled and currentSpeed or defaultSpeed

        local currentCamYaw = select(2, camera.CFrame:ToEulerAnglesYXZ())
        local yawDelta = currentCamYaw - lastCameraYaw
        if yawDelta > math.pi then yawDelta = yawDelta - (2 * math.pi) end
        if yawDelta < -math.pi then yawDelta = yawDelta + (2 * math.pi) end
        lastCameraYaw = currentCamYaw

        if isMoving and bhopMomentum > 30 and actualHorizontalVel < (bhopMomentum * 0.35) then
            bhopMomentum = baseGroundSpeed
        end

        isStrafing = false
        if UserInputService:IsKeyDown(Enum.KeyCode.A) and yawDelta > 0.003 then
            isStrafing = true
        elseif UserInputService:IsKeyDown(Enum.KeyCode.D) and yawDelta < -0.003 then
            isStrafing = true
        elseif math.abs(yawDelta) > 0.015 then
            isStrafing = true
        end

        if isGrounded then
            if isMoving then
                if not isStrafing and bhopMomentum > MAX_STRAIGHT_SPEED then
                    bhopMomentum = math.max(bhopMomentum - (STRAIGHT_BLEED_RATE * dt), MAX_STRAIGHT_SPEED)
                else
                    bhopMomentum = math.max(bhopMomentum * GROUND_MOMENTUM_LOSS, baseGroundSpeed)
                end

                local wantsToJump = autoJumpActive or UserInputService:IsKeyDown(Enum.KeyCode.Space)
                if wantsToJump then
                    local currentBoost = 0
                    if bhopMomentum < MAX_STRAIGHT_SPEED then
                        currentBoost = JUMP_INITIAL_BOOST
                    elseif isStrafing then
                        currentBoost = 1.0
                    end

                    bhopMomentum = math.clamp(bhopMomentum + currentBoost, baseGroundSpeed, MAX_BHOP_SPEED)
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)

                    local pushVec = moveDir.Unit * bhopMomentum
                    root.AssemblyLinearVelocity = Vector3.new(pushVec.X, currentVel.Y, pushVec.Z)
                end
            else
                bhopMomentum = baseGroundSpeed
            end
        else
            if isMoving then
                if isStrafing then
                    bhopMomentum = math.clamp(bhopMomentum + STRAFE_BOOST_AIR, 16, MAX_BHOP_SPEED)
                end

                local airVec = moveDir.Unit * bhopMomentum
                root.AssemblyLinearVelocity = Vector3.new(airVec.X, currentVel.Y, airVec.Z)
            end
        end

        speedNumLabel.Text = string.format("%.1f", actualHorizontalVel)

        local gaugeRel = math.clamp(actualHorizontalVel / MAX_BHOP_SPEED, 0.05, 1)
        gaugeFill.Size = UDim2.new(gaugeRel, 0, 1, 0)

        if actualHorizontalVel < 35 then
            hudStroke.Color = Color3.fromRGB(50, 140, 255)
            gaugeFill.BackgroundColor3 = Color3.fromRGB(50, 160, 255)
            unitLabel.TextColor3 = Color3.fromRGB(80, 180, 255)
        elseif actualHorizontalVel < 55.5 then
            hudStroke.Color = Color3.fromRGB(45, 215, 115)
            gaugeFill.BackgroundColor3 = Color3.fromRGB(45, 215, 115)
            unitLabel.TextColor3 = Color3.fromRGB(70, 240, 140)
        else
            hudStroke.Color = Color3.fromRGB(255, 95, 45)
            gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 95, 45)
            unitLabel.TextColor3 = Color3.fromRGB(255, 130, 70)
        end
    end

    -- 3. Universal Fly Controller
    if flyEnabled and flyVelocity and flyAlign and root and hum then
        local moveDir = Vector3.zero
        local padDir = hum.MoveDirection
        if padDir.Magnitude > 0 then
            local camCFrame = camera.CFrame
            local forwardMovement = padDir:Dot(camCFrame.LookVector)
            local rightMovement = padDir:Dot(camCFrame.RightVector)

            moveDir = (camCFrame.LookVector * forwardMovement) + (camCFrame.RightVector * rightMovement)
            if forwardMovement > 0.1 then
                moveDir = camCFrame.LookVector
            end
        end

        if mobileFlyUp then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if mobileFlyDown then moveDir = moveDir - Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            flyVelocity.VectorVelocity = moveDir.Unit * flySpeed
        else
            flyVelocity.VectorVelocity = Vector3.zero
        end
        flyAlign.CFrame = camera.CFrame
    end

    -- 4. Noclip Execution
    if noclipEnabled and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- 5. Auto-Dismiss Check (> 50 Studs)
    if isUIVisible and not isAnimating and root and uiPart and uiPart.Parent then
        local distFromPlayer = (uiPart.Position - root.Position).Magnitude
        if distFromPlayer > MAX_DISTANCE then
            hideUIWithAnimation()
        end
    end
    if isWardrobeVisible and not isWardrobeAnimating and root and wardrobePart and wardrobePart.Parent then
        local distWardrobe = (wardrobePart.Position - root.Position).Magnitude
        if distWardrobe > MAX_DISTANCE then
            hideWardrobeWithAnimation()
        end
    end
end)

-- ====================================================================
-- 2. Post-Camera Camlock Execution (à¸•à¸±à¸”à¸£à¸°à¸šà¸šà¸­à¸­à¹‚à¸•à¹‰à¹‚à¸«à¸¡à¸”à¹à¸¥à¸°à¸«à¸¡à¸¸à¸™à¸à¸¥à¹‰à¸­à¸‡à¸ˆà¸£à¸´à¸‡ 100%)
-- ====================================================================
local CAMLOCK_BIND_NAME = "SpatialUI_CamlockPostRender"
RunService:BindToRenderStep(CAMLOCK_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
    if isWardrobeMode or isWardrobeVisible then return end
    if camlockEnabled and isTargetLocked and lockedTargetPart then
        local targetChar = lockedTargetPart.Parent
        local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
        local myRoot = getRootPart()

        if targetHum and targetHum.Health > 0 and myRoot and (lockedTargetPart.Position - myRoot.Position).Magnitude <= (CAMLOCK_MAX_DIST * 1.25) then
            local currentCamPos = camera.CFrame.Position
            local targetPos = lockedTargetPart.Position
            
            -- à¸ªà¸£à¹‰à¸²à¸‡à¸¡à¸¸à¸¡à¸¡à¸­à¸‡à¸•à¸£à¸‡à¹„à¸›à¸¢à¸±à¸‡à¹€à¸›à¹‰à¸²à¸«à¸¡à¸²à¸¢ à¸“ à¸žà¸´à¸à¸±à¸”à¸›à¸±à¸ˆà¸ˆà¸¸à¸šà¸±à¸™à¸‚à¸­à¸‡à¸à¸¥à¹‰à¸­à¸‡à¸›à¸à¸•à¸´
            local targetLookCFrame = CFrame.lookAt(currentCamPos, targetPos)
            
            -- à¹€à¸‚à¸µà¸¢à¸™à¸—à¸±à¸šà¸¡à¸¸à¸¡à¸¡à¸­à¸‡à¸«à¸¥à¸±à¸‡à¸ˆà¸²à¸à¸—à¸µà¹ˆ CameraModule à¸„à¸³à¸™à¸§à¸“à¹€à¸ªà¸£à¹‡à¸ˆà¸ªà¸´à¹‰à¸™
            camera.CFrame = camera.CFrame:Lerp(targetLookCFrame, CAMLOCK_SMOOTHNESS)
        else
            isTargetLocked = false
            lockedTargetPart = nil
            updateCamlockButtonVisual(false)
        end
    end
end)

-- Close Button [X]
closeBtn.MouseButton1Click:Connect(function()
    RunService:UnbindFromRenderStep(CAMLOCK_BIND_NAME)
    if loopConnection then loopConnection:Disconnect() end
    stopFly()
    espEnabled = false
    updateESP()
    applyFullbright(false)

    cleanupOrbitController()

    if isWardrobeVisible then
        hideWardrobeWithAnimation()
    end
    restoreCharacterAppearance()

    camera.CameraType = Enum.CameraType.Custom
    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 128
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = defaultSpeed
        hum.JumpPower = defaultJump
    end
    local root = getRootPart()
    if root then
        root.Anchored = false
    end

    if uiPart then uiPart:Destroy() end
    if surfaceGui then surfaceGui:Destroy() end
    if backSurfaceGui then backSurfaceGui:Destroy() end
    if wardrobePart then wardrobePart:Destroy() end
    if wardrobeSurfaceGui then wardrobeSurfaceGui:Destroy() end
    if wardrobeBackSurfaceGui then wardrobeBackSurfaceGui:Destroy() end
    if screenHudGui then screenHudGui:Destroy() end
    if screenGui then screenGui:Destroy() end
    if mobileGui then mobileGui:Destroy() end
end)

-- Auto Summon on Execute & Re-summon on Respawn
task.spawn(function()
    local char = player.Character or player.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.4)
    if not isUIVisible and not isWardrobeVisible then
        summonUIWithAnimation()
    end
end)

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.5)
    if not isUIVisible and not isWardrobeVisible then
        summonUIWithAnimation()
    end
end)
