-- LocalScript for Executor / Client Environment
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

local targetGuiParent = player:WaitForChild("PlayerGui")

-- ====================================================================
-- Universal Variables & States
-- ====================================================================
local speedEnabled, currentSpeed, defaultSpeed = false, 16, 16
local jumpEnabled, currentJump, defaultJump = false, 50, 50
local noclipEnabled = false
local infJumpEnabled = false
local flyEnabled, flySpeed = false, 50
local espEnabled = false
local espPlayerColor = Color3.fromRGB(255, 60, 60)
local espNpcColor = Color3.fromRGB(50, 225, 90)
local espPlayerEnabled = true
local espNpcEnabled = true
local espFillTransparency = 0.5
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
local camlockTargetMode = "All" -- "All", "Players", "NPCs"
local camlockFovMode = "180" -- "180", "360"
local camlockShowFovCircle = true
local camlockUseFovLimit = true
local camlockFovRadius = 150
local camlockFovColor = Color3.fromRGB(40, 230, 255)
local CAMLOCK_SMOOTHNESS = 0.25 -- Camlock aim smoothness (0.15 - 0.4)
local CAMLOCK_MAX_DIST = 250
local isCharacterAliveAndValid, getBestTargetPart, getNearestTargetToCamera

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
        if distToHead <= 1.25 then
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
local camlockBtn, camlockStroke, camlockStatusText, camlockFovCircleFrame, camlockFovStroke
local setCamlockButtonVisible, updateCamlockButtonVisual, triggerCamlockAction, updateCamlockFovVisual
local setBhopScreenWidgets, triggerAutoJumpAction
local refreshFlyButtonsVisibility
local toggleEditWidgetPosition, stopEditingWidgetPosition, activeFuncListHud
local funcListContainer, refreshAllFuncPills, getMainTotalPixels

local hudConfig = {
    showSpeedHud = true,
    showAutoJumpBtn = true,
    showCamlockBtn = true,
    showFlyButtons = true,
    showActiveFuncList = true,

    speedHudCustomPos = UDim2.new(0, 25, 1, -85),
    autoJumpCustomPos = UDim2.new(1, -75, 0.65, 0),
    camlockCustomPos = UDim2.new(1, -75, 0.52, 0),
    flyButtonsCustomPos = UDim2.new(1, -75, 0.5, -60),
    funcListCustomPos = UDim2.new(1, -184, 0, 56),

    activeEditingWidget = nil,
    activeMoveBtnCallback = nil,
    isDraggingScreenWidget = false,
    widgetDragStartInputPos = nil,
    widgetDragStartAbsPos = nil,
}

local uiPart, surfaceGui, backSurfaceGui, container, sidebar, mainFrame
local backMainWindow, backSideWindow, sideSettingsWindow
local isSideSettingsOpen = false
local SIDE_PANEL_STUDS = 2.38
local closeSideSettingsWindow
local tabIndicator, titleLabel, closeBtn, minBtn, trackViewport, pagesTrack, grabBarContainer
local currentPartWidth, currentPartHeight = 4.8, 3.8
local currentTabIndex = 1
local typewriteTitle

local playerPage, visualsPage, settingsPage
local createToggleRow, createSliderRow, createActionButton
local createSubSlider, createSubToggle, createMovePositionRow, createKeybindRow, createSubSelector

local mobileGui, mobileFlyFrame
local flyAttachment, flyVelocity, flyAlign, startFly, stopFly
local updateESP, applyFullbright

local wardrobePart, wardrobeSurfaceGui, wardrobeBackSurfaceGui, wardrobeContainer, wardrobeMainWindow, wardrobeGrabBarContainer, wardrobeCloseBtn, wardrobePage
local wardrobeVisualBar, visualBar, resizeHandle, line1, line2
local profileBtn, profileStroke
local restoreCharacterAppearance, freezeCharacter, isHoveringWardrobeUI

local performZoomInAndAlign, performZoomOut
local summonUIWithAnimation, hideUIWithAnimation
local summonWardrobeWithAnimation, hideWardrobeWithAnimation
local updateToggleBtnState, cleanupOrbitController, setupOrbitController

-- ====================================================================
-- ScreenGui for On-Screen HUD Widgets & Interactive Position Editor
-- ====================================================================
screenHudGui = Instance.new("ScreenGui")
screenHudGui.Name = "SpatialUI_ScreenHUD"
screenHudGui.ResetOnSpawn = false
screenHudGui.DisplayOrder = 997
screenHudGui.Parent = targetGuiParent

-- ====================================================================
-- HUD Sub-Block 1: Active Functions List & Speedometer
-- ====================================================================
do
    -- [ 0. Right-Side Active Functions List (ArrayList HUD) ]
    funcListContainer = Instance.new("Frame")
    funcListContainer.Name = "ActiveFunctionsHUD"
    funcListContainer.Size = UDim2.new(0, 170, 0, 28)
    funcListContainer.AutomaticSize = Enum.AutomaticSize.Y
    funcListContainer.Position = hudConfig.funcListCustomPos
    funcListContainer.BackgroundTransparency = 1
    funcListContainer.Parent = screenHudGui

    local funcListLayout = Instance.new("UIListLayout")
    funcListLayout.FillDirection = Enum.FillDirection.Vertical
    funcListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    funcListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    funcListLayout.Padding = UDim.new(0, 5)
    funcListLayout.Parent = funcListContainer

    local funcHeaderPill = Instance.new("Frame")
    funcHeaderPill.Name = "HeaderBadge"
    funcHeaderPill.AutomaticSize = Enum.AutomaticSize.X
    funcHeaderPill.Size = UDim2.new(0, 0, 0, 20)
    funcHeaderPill.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
    funcHeaderPill.BackgroundTransparency = 0.25
    funcHeaderPill.LayoutOrder = 0
    funcHeaderPill.Visible = false
    funcHeaderPill.Parent = funcListContainer
    Instance.new("UICorner", funcHeaderPill).CornerRadius = UDim.new(0, 6)

    local funcHeaderPad = Instance.new("UIPadding", funcHeaderPill)
    funcHeaderPad.PaddingLeft = UDim.new(0, 8)
    funcHeaderPad.PaddingRight = UDim.new(0, 8)

    local funcHeaderLabel = Instance.new("TextLabel")
    funcHeaderLabel.AutomaticSize = Enum.AutomaticSize.X
    funcHeaderLabel.Size = UDim2.new(0, 0, 1, 0)
    funcHeaderLabel.BackgroundTransparency = 1
    funcHeaderLabel.Text = "ACTIVE FUNCTIONS"
    funcHeaderLabel.TextColor3 = Color3.fromRGB(110, 150, 215)
    funcHeaderLabel.Font = Enum.Font.GothamBold
    funcHeaderLabel.TextSize = 9
    funcHeaderLabel.TextXAlignment = Enum.TextXAlignment.Right
    funcHeaderLabel.Parent = funcHeaderPill

    local registeredFuncItems = {}
    local pageToFuncItem = {}
    local nextFuncOrder = 1

    local function getFormattedKeySuffix(item)
        local chosenKey = nil
        -- Prefer Toggle Keybind first if set, otherwise fall back to action keybind (e.g. Auto-Jump / Lock Target)
        for _, kb in ipairs(item.keybinds) do
            if kb.entry and kb.entry.key and tostring(kb.label):lower():find("toggle") then
                chosenKey = kb.entry.key.Name
                break
            end
        end
        if not chosenKey then
            for _, kb in ipairs(item.keybinds) do
                if kb.entry and kb.entry.key then
                    chosenKey = kb.entry.key.Name
                    break
                end
            end
        end
        return chosenKey
    end

    local function updateSingleFuncPill(item)
        if not hudConfig.showActiveFuncList or not item.isEnabled then
            if item.pill.Visible then
                item.pill.Visible = false
            end
            return false
        end

        local isActuallyActive = true
        if item.isTwoStage and item.checkSubActive then
            isActuallyActive = item.checkSubActive() and true or false
        end

        local keyName = getFormattedKeySuffix(item)
        if isActuallyActive then
            -- Active State -> Main UI Blue Accent Color
            if keyName then
                item.label.Text = string.format('<font color="#58A6FF">%s</font> <font color="#A6D4FF">[%s]</font>', item.name, keyName)
            else
                item.label.Text = string.format('<font color="#58A6FF">%s</font>', item.name)
            end
            TweenService:Create(item.accentBar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(50, 145, 255)
            }):Play()
            TweenService:Create(item.stroke, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Color = Color3.fromRGB(55, 135, 255),
                Transparency = 0.25
            }):Play()
            TweenService:Create(item.pill, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(16, 20, 30),
                BackgroundTransparency = 0.16
            }):Play()
        else
            -- Standby State (Two-stage function enabled in menu, waiting for actual trigger) -> Gray Color
            if keyName then
                item.label.Text = string.format('<font color="#8C92A4">%s</font> <font color="#707688">[%s]</font>', item.name, keyName)
            else
                item.label.Text = string.format('<font color="#8C92A4">%s</font>', item.name)
            end
            TweenService:Create(item.accentBar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(100, 105, 120)
            }):Play()
            TweenService:Create(item.stroke, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Color = Color3.fromRGB(75, 78, 92),
                Transparency = 0.45
            }):Play()
            TweenService:Create(item.pill, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(20, 21, 27),
                BackgroundTransparency = 0.3
            }):Play()
        end

        if not item.pill.Visible then
            item.pill.Visible = true
            item.scale.Scale = 0.8
            TweenService:Create(item.scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1
            }):Play()
        elseif item.lastActiveState ~= isActuallyActive then
            item.scale.Scale = 1.07
            TweenService:Create(item.scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1
            }):Play()
        end
        item.lastActiveState = isActuallyActive
        return true
    end

    refreshAllFuncPills = function()
        funcListContainer.Position = hudConfig.funcListCustomPos
        local anyVisible = false
        for _, item in ipairs(registeredFuncItems) do
            if updateSingleFuncPill(item) then
                anyVisible = true
            end
        end
        funcHeaderPill.Visible = (hudConfig.showActiveFuncList and anyVisible) or (hudConfig.activeEditingWidget == "funcList")
        funcListContainer.Visible = hudConfig.showActiveFuncList or (hudConfig.activeEditingWidget == "funcList")
    end

    activeFuncListHud = {
        register = function(funcName)
            if funcName == "Active Functions List" then return nil end

            local isTwoStage = false
            local checkSubActive = nil
            if funcName:find("Bunny Hop") then
                isTwoStage = true
                checkSubActive = function() return autoJumpActive end
            elseif funcName:find("Camlock") then
                isTwoStage = true
                checkSubActive = function() return isTargetLocked end
            end

            local pill = Instance.new("Frame")
            pill.Name = funcName .. "_Pill"
            pill.AutomaticSize = Enum.AutomaticSize.X
            pill.Size = UDim2.new(0, 0, 0, 26)
            pill.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
            pill.BackgroundTransparency = 0.18
            pill.BorderSizePixel = 0
            pill.LayoutOrder = nextFuncOrder
            nextFuncOrder = nextFuncOrder + 1
            pill.Visible = false
            pill.Parent = funcListContainer
            Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 7)

            local scale = Instance.new("UIScale", pill)
            scale.Scale = 1

            local stroke = Instance.new("UIStroke", pill)
            stroke.Color = Color3.fromRGB(55, 135, 255)
            stroke.Thickness = 1.2
            stroke.Transparency = 0.25

            local pad = Instance.new("UIPadding", pill)
            pad.PaddingLeft = UDim.new(0, 10)
            pad.PaddingRight = UDim.new(0, 14)

            local accentBar = Instance.new("Frame")
            accentBar.Name = "AccentBar"
            accentBar.AnchorPoint = Vector2.new(1, 0.5)
            accentBar.Size = UDim2.new(0, 3, 0, 14)
            accentBar.Position = UDim2.new(1, 9, 0.5, 0)
            accentBar.BackgroundColor3 = Color3.fromRGB(50, 145, 255)
            accentBar.BorderSizePixel = 0
            accentBar.Parent = pill
            Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

            local label = Instance.new("TextLabel")
            label.AutomaticSize = Enum.AutomaticSize.X
            label.Size = UDim2.new(0, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 12
            label.RichText = true
            label.TextColor3 = Color3.fromRGB(235, 242, 255)
            label.TextXAlignment = Enum.TextXAlignment.Right
            label.Text = funcName
            label.Parent = pill

            local item = {
                name = funcName,
                isEnabled = false,
                isTwoStage = isTwoStage,
                checkSubActive = checkSubActive,
                lastActiveState = nil,
                keybinds = {},
                pill = pill,
                scale = scale,
                stroke = stroke,
                accentBar = accentBar,
                label = label
            }
            table.insert(registeredFuncItems, item)
            return item
        end,
        bindSettingsPage = function(pageFrame, item)
            if pageFrame and item then
                pageToFuncItem[pageFrame] = item
            end
        end,
        attachKeybind = function(pageFrame, kbLabel, kbEntry)
            local item = pageFrame and pageToFuncItem[pageFrame]
            if item then
                table.insert(item.keybinds, { label = kbLabel, entry = kbEntry })
                updateSingleFuncPill(item)
            end
        end,
        setFuncEnabled = function(item, enabled)
            if not item then return end
            item.isEnabled = enabled
            refreshAllFuncPills()
        end,
        setHudVisible = function(visible)
            hudConfig.showActiveFuncList = visible
            refreshAllFuncPills()
        end,
        refresh = refreshAllFuncPills
    }

    -- [ 1. Speedometer HUD (Bottom Left) ]
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
end -- [End HUD Sub-Block 1]

-- ====================================================================
-- HUD Sub-Block 2: Auto Jump & Camlock Controls
-- ====================================================================
do
    -- [ 2. Auto Jump Button (Right Side) ]
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
        refreshAllFuncPills()
    end

    triggerAutoJumpAction = function()
        if not bhopEnabled then return end
        autoJumpActive = not autoJumpActive
        updateAutoJumpButtonVisual(autoJumpActive)
        if autoJumpBtn.Visible then
            autoJumpBtn.Size = UDim2.new(0, 52, 0, 52)
            TweenService:Create(autoJumpBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 56, 0, 56)
            }):Play()
        end
    end

    autoJumpBtn.Activated:Connect(function()
        if hudConfig.activeEditingWidget == "autoJump" then return end
        triggerAutoJumpAction()
    end)

    setBhopScreenWidgets = function(visible, overrideShowAuto, overrideShowHud)
        if overrideShowAuto ~= nil then hudConfig.showAutoJumpBtn = overrideShowAuto end
        if overrideShowHud ~= nil then hudConfig.showSpeedHud = overrideShowHud end

        local shouldShowHud = (visible and hudConfig.showSpeedHud) or (hudConfig.activeEditingWidget == "speedHud")
        local shouldShowAuto = (visible and hudConfig.showAutoJumpBtn) or (hudConfig.activeEditingWidget == "autoJump")

        if shouldShowHud then
            hudContainer.Visible = true
            TweenService:Create(hudContainer, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = hudConfig.speedHudCustomPos,
                GroupTransparency = 0
            }):Play()
        else
            local tweenLeft = TweenService:Create(hudContainer, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                GroupTransparency = 1
            })
            tweenLeft:Play()
            tweenLeft.Completed:Connect(function()
                if not ((bhopEnabled and hudConfig.showSpeedHud) or hudConfig.activeEditingWidget == "speedHud") then
                    hudContainer.Visible = false
                end
            end)
        end

        if shouldShowAuto then
            autoJumpBtn.Visible = true
            TweenService:Create(autoJumpBtn, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = hudConfig.autoJumpCustomPos
            }):Play()
        else
            autoJumpBtn.Visible = false
            if not bhopEnabled then
                autoJumpActive = false
                updateAutoJumpButtonVisual(false)
            end
        end
    end

    -- [ 3. Camlock Button (Right Side) ]
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

    -- [ 3.1 Camlock FOV Circle (Screen Center) ]
    camlockFovCircleFrame = Instance.new("Frame")
    camlockFovCircleFrame.Name = "CamlockFovCircle"
    camlockFovCircleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    camlockFovCircleFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    camlockFovCircleFrame.Size = UDim2.new(0, camlockFovRadius * 2, 0, camlockFovRadius * 2)
    camlockFovCircleFrame.BackgroundTransparency = 1
    camlockFovCircleFrame.Visible = false
    camlockFovCircleFrame.ZIndex = 1
    camlockFovCircleFrame.Parent = screenHudGui
    Instance.new("UICorner", camlockFovCircleFrame).CornerRadius = UDim.new(1, 0)

    camlockFovStroke = Instance.new("UIStroke", camlockFovCircleFrame)
    camlockFovStroke.Color = camlockFovColor
    camlockFovStroke.Thickness = 1.5
    camlockFovStroke.Transparency = 0.35

    updateCamlockFovVisual = function()
        if not camlockFovCircleFrame then return end
        local shouldShow = camlockEnabled and camlockShowFovCircle and not isWardrobeVisible and not isWardrobeMode
        camlockFovCircleFrame.Visible = shouldShow
        camlockFovCircleFrame.Size = UDim2.new(0, camlockFovRadius * 2, 0, camlockFovRadius * 2)
        if isTargetLocked then
            camlockFovStroke.Color = Color3.fromRGB(255, 60, 60)
            camlockFovStroke.Transparency = 0.15
        else
            camlockFovStroke.Color = camlockFovColor
            camlockFovStroke.Transparency = 0.35
        end
    end

    updateCamlockButtonVisual = function(isLocked, targetInfo)
        if isLocked then
            local nameStr = "LOCKED"
            if typeof(targetInfo) == "Instance" and targetInfo:IsA("Player") then
                nameStr = targetInfo.DisplayName
            elseif type(targetInfo) == "string" then
                nameStr = targetInfo
            elseif typeof(targetInfo) == "Instance" and targetInfo:IsA("Model") then
                nameStr = targetInfo.Name
            end
            if #nameStr > 6 then
                nameStr = nameStr:sub(1, 6) .. ".."
            end
            camlockStatusText.Text = nameStr
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
        if updateCamlockFovVisual then
            updateCamlockFovVisual()
        end
        refreshAllFuncPills()
    end

    getBestTargetPart = function(char)
        if not char or not char.Parent then return nil end
        -- Prioritize Head for headshot/aimlock
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") and head.Transparency < 0.95 then
            return head
        end
        -- Fallback to HumanoidRootPart or Torso
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") and root.Transparency < 0.95 then
            return root
        end
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if torso and torso:IsA("BasePart") and torso.Transparency < 0.95 then
            return torso
        end
        return nil
    end

    isCharacterAliveAndValid = function(char, targetPart)
        if not char or not char.Parent or char.Parent == game then return false end
        if not char:IsDescendantOf(Workspace) then return false end
        if char == player.Character then return false end
        if not targetPart or not targetPart.Parent or not targetPart:IsDescendantOf(Workspace) then return false end

        -- Reject camera descendants, viewmodels, cutscene rigs, fake arm models
        if char:IsDescendantOf(camera) or targetPart:IsDescendantOf(camera) then return false end

        local nameLower = char.Name:lower()
        if nameLower:find("viewmodel") or nameLower:find("arms") or nameLower:find("camera") or nameLower:find("ignore") then
            return false
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return false end

        -- Check health & state
        if hum.Health <= 0 then return false end
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Dead then return false end

        -- Check game death/knocked markers
        if char:GetAttribute("Dead") == true or char:GetAttribute("Downed") == true or char:GetAttribute("IsDead") == true or char:GetAttribute("Killed") == true then
            return false
        end
        local deadVal = char:FindFirstChild("Dead") or char:FindFirstChild("Downed") or char:FindFirstChild("IsDead") or char:FindFirstChild("Ragdoll")
        if deadVal and (deadVal:IsA("BoolValue") and deadVal.Value == true) then
            return false
        end

        -- If player, ensure this character is their CURRENT active character (not an old dead corpse)
        local targetPlayer = Players:GetPlayerFromCharacter(char)
        if targetPlayer then
            if targetPlayer.Character ~= char then
                return false
            end
        end

        -- Ensure target part is visible
        if targetPart.Transparency >= 0.95 then
            return false
        end

        return true
    end

    getNearestTargetToCamera = function()
        local myRoot = getRootPart()
        if not myRoot then return nil end

        local nearestTargetPart = nil
        local shortestDist = math.huge
        local camCF = camera.CFrame
        local camPos = camCF.Position
        local camLook = camCF.LookVector

        local function checkTargetCandidate(char, hum, part)
            if not char or not hum or not part then return end
            if not isCharacterAliveAndValid(char, part) then return end

            local toTarget = part.Position - camPos
            local worldDistance = toTarget.Magnitude
            if worldDistance > CAMLOCK_MAX_DIST then return end

            local dirToTarget = toTarget.Unit
            local dot = camLook:Dot(dirToTarget)

            local viewport = camera.ViewportSize
            local screenCenter = (viewport.X > 0 and viewport.Y > 0) and (viewport / 2) or Vector2.new(960, 540)
            local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude

            -- FOV circle limit check
            if camlockUseFovLimit then
                if not onScreen or screenDist > camlockFovRadius then
                    return
                end
            elseif camlockFovMode == "180" and dot < 0 then
                -- 180 FOV: must be in front of camera (dot >= 0)
                return
            end

            -- Scoring: favor closer to crosshair/screen center, plus world distance
            local totalScore
            if camlockUseFovLimit then
                totalScore = screenDist + (worldDistance * 0.5)
            else
                local anglePenalty = (1 - dot) * 90
                totalScore = anglePenalty + (worldDistance * 0.75)
            end

            if totalScore < shortestDist then
                shortestDist = totalScore
                nearestTargetPart = part
            end
        end

        -- 1. Scan Players if mode is "All" or "Players"
        if camlockTargetMode == "All" or camlockTargetMode == "Players" then
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:IsDescendantOf(Workspace) then
                    local targetChar = otherPlayer.Character
                    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                    local targetPart = getBestTargetPart(targetChar)
                    if targetHum and targetPart then
                        checkTargetCandidate(targetChar, targetHum, targetPart)
                    end
                end
            end
        end

        -- 2. Scan Alive NPCs if mode is "All" or "NPCs"
        if camlockTargetMode == "All" or camlockTargetMode == "NPCs" then
            local function scanForNPCs(parentObj, depth)
                if depth > 3 then return end
                for _, obj in ipairs(parentObj:GetChildren()) do
                    if obj:IsA("Model") and obj ~= player.Character and not obj:IsDescendantOf(camera) then
                        local hum = obj:FindFirstChildOfClass("Humanoid")
                        if hum and not Players:GetPlayerFromCharacter(obj) then
                            local part = getBestTargetPart(obj)
                            if part then
                                checkTargetCandidate(obj, hum, part)
                            end
                        else
                            if depth < 3 and not obj:FindFirstChildOfClass("Humanoid") then
                                scanForNPCs(obj, depth + 1)
                            end
                        end
                    elseif obj:IsA("Folder") and obj ~= camera then
                        scanForNPCs(obj, depth + 1)
                    end
                end
            end
            scanForNPCs(Workspace, 1)
        end

        return nearestTargetPart
    end

    triggerCamlockAction = function()
        if not camlockEnabled then return end
        if not isTargetLocked then
            local target = getNearestTargetToCamera()
            if target then
                lockedTargetPart = target
                isTargetLocked = true
                local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
                updateCamlockButtonVisual(true, targetPlayer or target.Parent.Name)
            else
                camlockStroke.Color = Color3.fromRGB(255, 160, 40)
                if camlockFovStroke then
                    camlockFovStroke.Color = Color3.fromRGB(255, 160, 40)
                end
                task.delay(0.25, function()
                    if not isTargetLocked then
                        camlockStroke.Color = Color3.fromRGB(60, 60, 80)
                        if camlockFovStroke then
                            camlockFovStroke.Color = camlockFovColor
                        end
                    end
                end)
            end
        else
            isTargetLocked = false
            lockedTargetPart = nil
            updateCamlockButtonVisual(false)
        end

        if camlockBtn.Visible then
            camlockBtn.Size = UDim2.new(0, 52, 0, 52)
            TweenService:Create(camlockBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 56, 0, 56)
            }):Play()
        end
    end

    camlockBtn.Activated:Connect(function()
        if hudConfig.activeEditingWidget == "camlock" then return end
        triggerCamlockAction()
    end)

    setCamlockButtonVisible = function(visible, overrideShowBtn)
        if overrideShowBtn ~= nil then
            hudConfig.showCamlockBtn = overrideShowBtn
        end
        local shouldShow = (visible and hudConfig.showCamlockBtn) or (hudConfig.activeEditingWidget == "camlock")
        if shouldShow then
            camlockBtn.Visible = true
            TweenService:Create(camlockBtn, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = hudConfig.camlockCustomPos
            }):Play()
        else
            camlockBtn.Visible = false
            if not camlockEnabled then
                isTargetLocked = false
                lockedTargetPart = nil
                updateCamlockButtonVisual(false)
            end
        end
    end

    refreshFlyButtonsVisibility = function(overrideShowFly)
        if overrideShowFly ~= nil then
            hudConfig.showFlyButtons = overrideShowFly
        end
        if not mobileFlyFrame then return end
        local shouldShow = (flyEnabled and hudConfig.showFlyButtons) or (hudConfig.activeEditingWidget == "flyBtns")
        mobileFlyFrame.Position = hudConfig.flyButtonsCustomPos
        mobileFlyFrame.Visible = shouldShow
    end
end -- [End HUD Sub-Block 2]

-- ====================================================================
-- HUD Sub-Block 3: Interactive Position Editor Overlay
-- ====================================================================
do
    -- [ 4. Interactive Screen Button Position Mover Overlay ]
    local editHighlightOverlay = Instance.new("Frame")
    editHighlightOverlay.Name = "WidgetMoveOverlay"
    editHighlightOverlay.BackgroundTransparency = 0.75
    editHighlightOverlay.BackgroundColor3 = Color3.fromRGB(40, 140, 255)
    editHighlightOverlay.BorderSizePixel = 0
    editHighlightOverlay.Visible = false
    editHighlightOverlay.ZIndex = 50
    editHighlightOverlay.Active = true
    editHighlightOverlay.Parent = screenHudGui
    Instance.new("UICorner", editHighlightOverlay).CornerRadius = UDim.new(0, 14)

    local editOverlayStroke = Instance.new("UIStroke", editHighlightOverlay)
    editOverlayStroke.Color = Color3.fromRGB(90, 210, 255)
    editOverlayStroke.Thickness = 2.2

    local editDragTag = Instance.new("TextLabel")
    editDragTag.Size = UDim2.new(0, 110, 0, 18)
    editDragTag.AnchorPoint = Vector2.new(0.5, 1)
    editDragTag.Position = UDim2.new(0.5, 0, 0, -4)
    editDragTag.BackgroundColor3 = Color3.fromRGB(20, 30, 48)
    editDragTag.Text = "DRAG TO MOVE"
    editDragTag.TextColor3 = Color3.fromRGB(110, 215, 255)
    editDragTag.Font = Enum.Font.GothamBold
    editDragTag.TextSize = 10
    editDragTag.ZIndex = 51
    editDragTag.Parent = editHighlightOverlay
    Instance.new("UICorner", editDragTag).CornerRadius = UDim.new(0, 6)

    local editSavePill = Instance.new("TextButton")
    editSavePill.Size = UDim2.new(0, 68, 0, 20)
    editSavePill.AnchorPoint = Vector2.new(0.5, 0)
    editSavePill.Position = UDim2.new(0.5, 0, 1, 4)
    editSavePill.BackgroundColor3 = Color3.fromRGB(40, 185, 105)
    editSavePill.Text = "Save Pos"
    editSavePill.TextColor3 = Color3.fromRGB(255, 255, 255)
    editSavePill.Font = Enum.Font.GothamBold
    editSavePill.TextSize = 10
    editSavePill.ZIndex = 52
    editSavePill.Parent = editHighlightOverlay
    Instance.new("UICorner", editSavePill).CornerRadius = UDim.new(0, 6)

    local function getWidgetInstance(widgetId)
        if widgetId == "autoJump" then return autoJumpBtn
        elseif widgetId == "speedHud" then return hudContainer
        elseif widgetId == "camlock" then return camlockBtn
        elseif widgetId == "flyBtns" then return mobileFlyFrame
        elseif widgetId == "funcList" then return funcListContainer
        end
        return nil
    end

    local function syncOverlayToTarget()
        local target = getWidgetInstance(hudConfig.activeEditingWidget)
        if not target then
            editHighlightOverlay.Visible = false
            return
        end
        local sizeY = math.max(36, target.AbsoluteSize.Y)
        editHighlightOverlay.Size = UDim2.new(0, target.AbsoluteSize.X + 8, 0, sizeY + 8)
        editHighlightOverlay.Position = UDim2.new(0, target.AbsolutePosition.X - 4, 0, target.AbsolutePosition.Y - 4)
        editHighlightOverlay.Visible = true
    end

    stopEditingWidgetPosition = function()
        if not hudConfig.activeEditingWidget then return end
        local prevCallback = hudConfig.activeMoveBtnCallback
        hudConfig.activeEditingWidget = nil
        hudConfig.activeMoveBtnCallback = nil
        hudConfig.isDraggingScreenWidget = false
        editHighlightOverlay.Visible = false
        if prevCallback then prevCallback(false) end

        setBhopScreenWidgets(bhopEnabled)
        setCamlockButtonVisible(camlockEnabled)
        refreshFlyButtonsVisibility()
        refreshAllFuncPills()
    end

    toggleEditWidgetPosition = function(widgetId, onStateChange)
        if hudConfig.activeEditingWidget == widgetId then
            stopEditingWidgetPosition()
            return
        end
        if hudConfig.activeEditingWidget then
            stopEditingWidgetPosition()
        end

        hudConfig.activeEditingWidget = widgetId
        hudConfig.activeMoveBtnCallback = onStateChange
        if onStateChange then onStateChange(true) end

        setBhopScreenWidgets(bhopEnabled)
        setCamlockButtonVisible(camlockEnabled)
        refreshFlyButtonsVisibility()
        refreshAllFuncPills()

        task.defer(syncOverlayToTarget)
    end

    editSavePill.Activated:Connect(function()
        stopEditingWidgetPosition()
    end)

    editHighlightOverlay.InputBegan:Connect(function(input)
        if not hudConfig.activeEditingWidget then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local target = getWidgetInstance(hudConfig.activeEditingWidget)
            if target then
                hudConfig.isDraggingScreenWidget = true
                hudConfig.widgetDragStartInputPos = input.Position
                hudConfig.widgetDragStartAbsPos = target.AbsolutePosition
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not hudConfig.isDraggingScreenWidget or not hudConfig.activeEditingWidget then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local target = getWidgetInstance(hudConfig.activeEditingWidget)
            if target and hudConfig.widgetDragStartInputPos and hudConfig.widgetDragStartAbsPos then
                local delta = input.Position - hudConfig.widgetDragStartInputPos
                local vp = camera.ViewportSize
                local newX = math.clamp(hudConfig.widgetDragStartAbsPos.X + delta.X, 6, math.max(6, vp.X - target.AbsoluteSize.X - 6))
                local newY = math.clamp(hudConfig.widgetDragStartAbsPos.Y + delta.Y, 6, math.max(6, vp.Y - target.AbsoluteSize.Y - 6))
                local newUDim = UDim2.new(0, newX, 0, newY)

                target.Position = newUDim
                if hudConfig.activeEditingWidget == "autoJump" then
                    hudConfig.autoJumpCustomPos = newUDim
                elseif hudConfig.activeEditingWidget == "speedHud" then
                    hudConfig.speedHudCustomPos = newUDim
                elseif hudConfig.activeEditingWidget == "camlock" then
                    hudConfig.camlockCustomPos = newUDim
                elseif hudConfig.activeEditingWidget == "flyBtns" then
                    hudConfig.flyButtonsCustomPos = newUDim
                elseif hudConfig.activeEditingWidget == "funcList" then
                    hudConfig.funcListCustomPos = newUDim
                end
                syncOverlayToTarget()
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            hudConfig.isDraggingScreenWidget = false
        end
    end)
end -- [End HUD Sub-Block 3]

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
surfaceGui.AlwaysOnTop = false
surfaceGui.ResetOnSpawn = false
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
backSurfaceGui.ResetOnSpawn = false
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

getMainTotalPixels = function()
    return math.round(currentPartWidth * 100)
end

backMainWindow = Instance.new("Frame")
backMainWindow.Name = "BackMainWindow"
backMainWindow.Size = UDim2.new(0, getMainTotalPixels() - 60, 1, -55)
backMainWindow.Position = UDim2.new(1, -getMainTotalPixels(), 0, 0)
backMainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
backMainWindow.BorderSizePixel = 0
backMainWindow.Parent = backContainer
Instance.new("UICorner", backMainWindow).CornerRadius = UDim.new(0, 16)

local backMainStroke = Instance.new("UIStroke", backMainWindow)
backMainStroke.Color = Color3.fromRGB(65, 65, 80)
backMainStroke.Thickness = 1.5

backSideWindow = Instance.new("Frame")
backSideWindow.Name = "BackSideSettingsWindow"
backSideWindow.Size = UDim2.new(0, 230, 1, -55)
backSideWindow.Position = UDim2.new(0, 0, 0, 0)
backSideWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
backSideWindow.BorderSizePixel = 0
backSideWindow.Visible = false
backSideWindow.Parent = backContainer
Instance.new("UICorner", backSideWindow).CornerRadius = UDim.new(0, 16)

local backSideStroke = Instance.new("UIStroke", backSideWindow)
backSideStroke.Color = Color3.fromRGB(65, 95, 145)
backSideStroke.Thickness = 1.5

-- Front Sidebar
sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 52, 1, -55)
sidebar.Position = UDim2.new(0, 0, 0, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
sidebar.BorderSizePixel = 0
sidebar.Parent = container
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 16)

local sidebarScale = Instance.new("UIScale", sidebar)
sidebarScale.Scale = 1

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

-- Front MainWindow (Pixel-locked width so opening/closing side window never squishes or snaps MainWindow)
mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.new(0, getMainTotalPixels() - 60, 1, -55)
mainFrame.Position = UDim2.new(0, 60, 0, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = container
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

local mainFrameScale = Instance.new("UIScale", mainFrame)
mainFrameScale.Scale = 1

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
titleLabel.ZIndex = 3
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
closeBtn.ZIndex = 3
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
minBtn.ZIndex = 3
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

pagesTrack = Instance.new("Frame")
pagesTrack.Name = "PagesTrack"
pagesTrack.Size = UDim2.new(3, 0, 1, 0)
pagesTrack.Position = UDim2.new(0, 0, 0, 0)
pagesTrack.BackgroundTransparency = 1
pagesTrack.BorderSizePixel = 0
pagesTrack.Parent = trackViewport

local trackLayout = Instance.new("UIListLayout")
trackLayout.FillDirection = Enum.FillDirection.Horizontal
trackLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackLayout.Parent = pagesTrack

local function createPageColumn(order)
    local col = Instance.new("ScrollingFrame")
    col.Size = UDim2.new(1 / 3, 0, 1, 0)
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

playerPage = createPageColumn(1)
visualsPage = createPageColumn(2)
settingsPage = createPageColumn(3)
end -- [End 3D Part & SurfaceGui Setup]

-- ====================================================================
-- Universal UI Component Builder (Side Settings Window & Keybinds)
-- ====================================================================
do
    local registeredKeybinds = {}
    local activeBindingEntry = nil
    local activeSettingsOwner = nil
    local sideTitleThread = nil
    local sideCloseDisconnectId = 0

    -- Separate Floating Side Settings Window (Right Side of MainWindow)
    sideSettingsWindow = Instance.new("CanvasGroup")
    sideSettingsWindow.Name = "SideSettingsWindow"
    sideSettingsWindow.Size = UDim2.new(0, 230, 1, -55)
    sideSettingsWindow.Position = UDim2.new(0, getMainTotalPixels() - 55, 0, 14)
    sideSettingsWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    sideSettingsWindow.BorderSizePixel = 0
    sideSettingsWindow.GroupTransparency = 1
    sideSettingsWindow.Visible = false
    sideSettingsWindow.ZIndex = 1
    sideSettingsWindow.Parent = container
    Instance.new("UICorner", sideSettingsWindow).CornerRadius = UDim.new(0, 16)

    local sideWindowScale = Instance.new("UIScale", sideSettingsWindow)
    sideWindowScale.Scale = 0.84

    local sideWindowStroke = Instance.new("UIStroke", sideSettingsWindow)
    sideWindowStroke.Color = Color3.fromRGB(65, 115, 195)
    sideWindowStroke.Thickness = 1.5

    local sideHeaderIcon = Instance.new("ImageLabel")
    sideHeaderIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    sideHeaderIcon.Size = UDim2.new(0, 16, 0, 16)
    sideHeaderIcon.Position = UDim2.new(0, 22, 0, 20)
    sideHeaderIcon.BackgroundTransparency = 1
    sideHeaderIcon.Image = "rbxassetid://10734950309"
    sideHeaderIcon.ImageColor3 = Color3.fromRGB(95, 175, 255)
    sideHeaderIcon.Parent = sideSettingsWindow

    local sideWindowTitle = Instance.new("TextLabel")
    sideWindowTitle.Size = UDim2.new(1, -70, 0, 20)
    sideWindowTitle.Position = UDim2.new(0, 36, 0, 8)
    sideWindowTitle.BackgroundTransparency = 1
    sideWindowTitle.Text = "Settings"
    sideWindowTitle.TextColor3 = Color3.fromRGB(235, 240, 255)
    sideWindowTitle.Font = Enum.Font.GothamBold
    sideWindowTitle.TextSize = 13
    sideWindowTitle.TextXAlignment = Enum.TextXAlignment.Left
    sideWindowTitle.TextTruncate = Enum.TextTruncate.AtEnd
    sideWindowTitle.Parent = sideSettingsWindow

    local sideWindowSub = Instance.new("TextLabel")
    sideWindowSub.Size = UDim2.new(1, -70, 0, 12)
    sideWindowSub.Position = UDim2.new(0, 36, 0, 26)
    sideWindowSub.BackgroundTransparency = 1
    sideWindowSub.Text = "FUNCTION CONFIG"
    sideWindowSub.TextColor3 = Color3.fromRGB(105, 130, 175)
    sideWindowSub.Font = Enum.Font.GothamBold
    sideWindowSub.TextSize = 9
    sideWindowSub.TextXAlignment = Enum.TextXAlignment.Left
    sideWindowSub.Parent = sideSettingsWindow

    local sideCloseBtn = Instance.new("TextButton")
    sideCloseBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    sideCloseBtn.Size = UDim2.new(0, 24, 0, 24)
    sideCloseBtn.Position = UDim2.new(1, -20, 0, 22)
    sideCloseBtn.BackgroundColor3 = Color3.fromRGB(42, 44, 58)
    sideCloseBtn.Text = "X"
    sideCloseBtn.TextColor3 = Color3.fromRGB(210, 215, 230)
    sideCloseBtn.Font = Enum.Font.GothamBold
    sideCloseBtn.TextSize = 12
    sideCloseBtn.Parent = sideSettingsWindow
    Instance.new("UICorner", sideCloseBtn).CornerRadius = UDim.new(0, 6)

    local sideDivider = Instance.new("Frame")
    sideDivider.Size = UDim2.new(1, -24, 0, 2)
    sideDivider.Position = UDim2.new(0, 12, 0, 44)
    sideDivider.BackgroundColor3 = Color3.fromRGB(35, 40, 56)
    sideDivider.BorderSizePixel = 0
    sideDivider.Parent = sideSettingsWindow
    Instance.new("UICorner", sideDivider).CornerRadius = UDim.new(1, 0)

    local sideDividerFill = Instance.new("Frame")
    sideDividerFill.Size = UDim2.new(1, 0, 1, 0)
    sideDividerFill.BackgroundColor3 = Color3.fromRGB(70, 155, 255)
    sideDividerFill.BorderSizePixel = 0
    sideDividerFill.Parent = sideDivider
    Instance.new("UICorner", sideDividerFill).CornerRadius = UDim.new(1, 0)

    local sideContentHost = Instance.new("Frame")
    sideContentHost.Name = "SideContentHost"
    sideContentHost.Size = UDim2.new(1, 0, 1, -48)
    sideContentHost.Position = UDim2.new(0, 0, 0, 48)
    sideContentHost.BackgroundTransparency = 1
    sideContentHost.ClipsDescendants = true
    sideContentHost.Parent = sideSettingsWindow

    local function typewriteSideTitle(targetText)
        if sideTitleThread then task.cancel(sideTitleThread) end
        sideTitleThread = task.spawn(function()
            local current = ""
            for i = 1, #targetText do
                local nextChar = targetText:sub(i, i)
                sideWindowTitle.Text = current .. scrambleChars[math.random(1, #scrambleChars)]
                task.wait(0.01)
                current = current .. nextChar
                sideWindowTitle.Text = current
            end
            sideWindowTitle.Text = targetText
        end)
    end

    local function animateSubItemsIn(pageFrame)
        if not pageFrame then return end
        local items = {}
        for _, child in ipairs(pageFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                table.insert(items, child)
            end
        end
        table.sort(items, function(a, b)
            return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
        end)
        for idx, item in ipairs(items) do
            local sc = item:FindFirstChildOfClass("UIScale")
            if not sc then
                sc = Instance.new("UIScale")
                sc.Parent = item
            end
            sc.Scale = 0.86
            item.BackgroundTransparency = 0.55
            task.delay((idx - 1) * 0.038, function()
                if item and item.Parent then
                    TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Scale = 1
                    }):Play()
                    TweenService:Create(item, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 0
                    }):Play()
                end
            end)
        end
    end

    closeSideSettingsWindow = function(instant)
        sideCloseDisconnectId = sideCloseDisconnectId + 1
        local myCloseId = sideCloseDisconnectId

        if activeSettingsOwner then
            activeSettingsOwner.setHighlight(false)
            local prevOwner = activeSettingsOwner
            activeSettingsOwner = nil
            if instant and prevOwner.page then
                prevOwner.page.Visible = false
            else
                task.delay(0.24, function()
                    if activeSettingsOwner ~= prevOwner and prevOwner.page then
                        prevOwner.page.Visible = false
                    end
                end)
            end
        end

        if not isSideSettingsOpen then return end
        isSideSettingsOpen = false
        backSideWindow.Visible = false

        local mainTotalPx = getMainTotalPixels()
        mainFrame.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
        backMainWindow.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
        backMainWindow.Position = UDim2.new(1, -mainTotalPx, 0, 0)

        if instant or not isUIVisible then
            sideSettingsWindow.Visible = false
            sideSettingsWindow.GroupTransparency = 1
            sideWindowScale.Scale = 0.84
            if isUIVisible and uiPart then
                uiPart.Size = Vector3.new(currentPartWidth, currentPartHeight, 0.05)
            end
            return
        end

        TweenService:Create(sideHeaderIcon, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Rotation = -90
        }):Play()

        TweenService:Create(uiPart, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = Vector3.new(currentPartWidth, currentPartHeight, 0.05)
        }):Play()

        TweenService:Create(sideWindowScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Scale = 0.82
        }):Play()

        local foldIn = TweenService:Create(sideSettingsWindow, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            GroupTransparency = 1,
            Position = UDim2.new(0, mainTotalPx - 58, 0, 16)
        })
        foldIn:Play()
        foldIn.Completed:Connect(function()
            if sideCloseDisconnectId == myCloseId and not isSideSettingsOpen then
                sideSettingsWindow.Visible = false
            end
        end)
    end

    local function openSideSettingsFor(ownerEntry)
        if interactionState ~= "IDLE" then return end
        sideCloseDisconnectId = sideCloseDisconnectId + 1

        -- Clicking the same function again closes the side window
        if activeSettingsOwner == ownerEntry and isSideSettingsOpen then
            closeSideSettingsWindow(false)
            return
        end

        -- Only ONE function's settings can be open at a time: deactivate previous owner
        if activeSettingsOwner and activeSettingsOwner ~= ownerEntry then
            activeSettingsOwner.setHighlight(false)
            if activeSettingsOwner.page then
                activeSettingsOwner.page.Visible = false
            end
        end

        activeSettingsOwner = ownerEntry
        ownerEntry.setHighlight(true)
        typewriteSideTitle(ownerEntry.name)

        if ownerEntry.page then
            ownerEntry.page.CanvasPosition = Vector2.zero
            ownerEntry.page.Visible = true
            animateSubItemsIn(ownerEntry.page)
        end

        local mainTotalPx = getMainTotalPixels()
        mainFrame.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
        backMainWindow.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
        backMainWindow.Position = UDim2.new(1, -mainTotalPx, 0, 0)

        -- Header icon spin + divider sweep + rim glow pulse
        sideHeaderIcon.Rotation = -110
        TweenService:Create(sideHeaderIcon, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Rotation = 0
        }):Play()

        sideDividerFill.Size = UDim2.new(0, 0, 1, 0)
        TweenService:Create(sideDividerFill, TweenInfo.new(0.44, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()

        sideWindowStroke.Color = Color3.fromRGB(115, 205, 255)
        TweenService:Create(sideWindowStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(65, 115, 195)
        }):Play()

        if not isSideSettingsOpen then
            isSideSettingsOpen = true
            backSideWindow.Visible = true

            sideSettingsWindow.Position = UDim2.new(0, mainTotalPx - 58, 0, 16)
            sideSettingsWindow.GroupTransparency = 1
            sideWindowScale.Scale = 0.82
            sideSettingsWindow.Visible = true

            TweenService:Create(uiPart, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = Vector3.new(currentPartWidth + SIDE_PANEL_STUDS, currentPartHeight, 0.05)
            }):Play()

            TweenService:Create(sideWindowScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1
            }):Play()

            TweenService:Create(sideSettingsWindow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                GroupTransparency = 0
            }):Play()

            TweenService:Create(sideSettingsWindow, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, mainTotalPx + 8, 0, 0)
            }):Play()
        else
            -- Crisp spring pop when switching between functions
            sideWindowScale.Scale = 0.94
            sideSettingsWindow.Position = UDim2.new(0, mainTotalPx + 18, 0, 5)
            TweenService:Create(sideWindowScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1
            }):Play()
            TweenService:Create(sideSettingsWindow, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, mainTotalPx + 8, 0, 0)
            }):Play()
        end
    end

    sideCloseBtn.Activated:Connect(function()
        if interactionState ~= "IDLE" then return end
        sideCloseBtn.Size = UDim2.new(0, 19, 0, 19)
        TweenService:Create(sideCloseBtn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 24, 0, 24)
        }):Play()
        closeSideSettingsWindow(false)
    end)

    local function formatKeyName(keyCode)
        if not keyCode then return "None" end
        return keyCode.Name or "None"
    end

    local function attachSubItemDecor(row, dotColor)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Color = Color3.fromRGB(40, 45, 62)
        rowStroke.Thickness = 1
        rowStroke.Transparency = 0.35

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 5, 0, 5)
        dot.AnchorPoint = Vector2.new(0, 0.5)
        dot.Position = UDim2.new(0, 10, 0.5, 0)
        dot.BackgroundColor3 = dotColor or Color3.fromRGB(70, 150, 255)
        dot.BorderSizePixel = 0
        dot.Parent = row
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        return dot
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if UserInputService:GetFocusedTextBox() then return end

        if activeBindingEntry then
            local entry = activeBindingEntry
            activeBindingEntry = nil
            if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Escape then
                entry.key = nil
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                entry.key = input.KeyCode
            end
            entry.updateVisual(false)
            return
        end

        if gameProcessed then return end
        for _, entry in ipairs(registeredKeybinds) do
            if entry.key and entry.key == input.KeyCode and entry.onTrigger then
                entry.onTrigger()
            end
        end
    end)

    createSubSlider = function(parent, name, minVal, maxVal, defaultVal, onSliderChange, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 52)
        row.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
        row.LayoutOrder = order or 1
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local dot = attachSubItemDecor(row, Color3.fromRGB(70, 155, 255))
        dot.Position = UDim2.new(0, 10, 0, 15)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 0, 20)
        label.Position = UDim2.new(0, 21, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(205, 215, 235)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local valBadge = Instance.new("Frame")
        valBadge.Size = UDim2.new(0, 42, 0, 18)
        valBadge.Position = UDim2.new(1, -50, 0, 6)
        valBadge.BackgroundColor3 = Color3.fromRGB(34, 42, 62)
        valBadge.BorderSizePixel = 0
        valBadge.Parent = row
        Instance.new("UICorner", valBadge).CornerRadius = UDim.new(0, 5)

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(1, 0, 1, 0)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(defaultVal)
        valLabel.TextColor3 = Color3.fromRGB(115, 195, 255)
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextSize = 11
        valLabel.Parent = valBadge

        local sliderBar = Instance.new("Frame")
        sliderBar.Size = UDim2.new(1, -24, 0, 6)
        sliderBar.Position = UDim2.new(0, 12, 0, 35)
        sliderBar.BackgroundColor3 = Color3.fromRGB(40, 44, 60)
        sliderBar.BorderSizePixel = 0
        sliderBar.Parent = row
        Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(1, 0)

        local initialPercent = math.clamp((defaultVal - minVal) / math.max(1, maxVal - minVal), 0, 1)
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(55, 140, 255)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBar
        Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

        local sliderKnob = Instance.new("TextButton")
        sliderKnob.Name = "Knob"
        sliderKnob.Size = UDim2.new(0, 14, 0, 14)
        sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        sliderKnob.Position = UDim2.new(initialPercent, 0, 0.5, 0)
        sliderKnob.BackgroundColor3 = Color3.fromRGB(245, 248, 255)
        sliderKnob.Text = ""
        sliderKnob.AutoButtonColor = false
        sliderKnob.Parent = sliderBar
        Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

        local isHoldingKnob = false
        local knobTouchId = nil

        local function setSliderValue(canvasX)
            local rel = math.clamp((canvasX - sliderBar.AbsolutePosition.X) / math.max(1, sliderBar.AbsoluteSize.X), 0, 1)
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
                TweenService:Create(sliderKnob, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(245, 248, 255)}):Play()
                if interactionState == "SLIDING" then
                    interactionState = "IDLE"
                end
            end
        end

        sliderKnob.InputEnded:Connect(releaseKnob)
        UserInputService.InputEnded:Connect(releaseKnob)
        return row
    end

    createSubToggle = function(parent, name, defaultState, onToggle, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
        row.LayoutOrder = order or 1
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        attachSubItemDecor(row, Color3.fromRGB(65, 205, 130))

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -82, 1, 0)
        label.Position = UDim2.new(0, 20, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(205, 215, 235)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 54, 0, 22)
        toggleBtn.Position = UDim2.new(1, -62, 0.5, -11)
        toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(45, 180, 100) or Color3.fromRGB(48, 50, 66)
        toggleBtn.Text = defaultState and "ON" or "OFF"
        toggleBtn.TextColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 180, 198)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 11
        toggleBtn.Parent = row
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

        local isToggled = defaultState
        toggleBtn.Activated:Connect(function()
            if interactionState ~= "IDLE" then return end
            isToggled = not isToggled
            if isToggled then
                toggleBtn.Text = "ON"
                TweenService:Create(toggleBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(45, 180, 100), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            else
                toggleBtn.Text = "OFF"
                TweenService:Create(toggleBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(48, 50, 66), TextColor3 = Color3.fromRGB(175, 180, 198)}):Play()
            end
            onToggle(isToggled)
        end)
        return row
    end

    createMovePositionRow = function(parent, name, widgetId, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
        row.LayoutOrder = order or 1
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        attachSubItemDecor(row, Color3.fromRGB(90, 175, 255))

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -96, 1, 0)
        label.Position = UDim2.new(0, 20, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(205, 215, 235)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row

        local moveBtn = Instance.new("TextButton")
        moveBtn.Size = UDim2.new(0, 68, 0, 22)
        moveBtn.Position = UDim2.new(1, -76, 0.5, -11)
        moveBtn.BackgroundColor3 = Color3.fromRGB(45, 110, 215)
        moveBtn.Text = "Move Pos"
        moveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        moveBtn.Font = Enum.Font.GothamBold
        moveBtn.TextSize = 10
        moveBtn.Parent = row
        Instance.new("UICorner", moveBtn).CornerRadius = UDim.new(0, 6)

        local function updateMoveBtnVisual(editing)
            if editing then
                moveBtn.Text = "Save Pos"
                TweenService:Create(moveBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(40, 185, 105)}):Play()
            else
                moveBtn.Text = "Move Pos"
                TweenService:Create(moveBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(45, 110, 215)}):Play()
            end
        end

        moveBtn.Activated:Connect(function()
            if interactionState ~= "IDLE" then return end
            toggleEditWidgetPosition(widgetId, updateMoveBtnVisual)
        end)
        return row
    end

    createKeybindRow = function(parent, name, defaultKeyCode, onTrigger, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
        row.LayoutOrder = order or 1
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        attachSubItemDecor(row, Color3.fromRGB(165, 130, 255))

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -96, 1, 0)
        label.Position = UDim2.new(0, 20, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(205, 215, 235)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 68, 0, 22)
        keyBtn.Position = UDim2.new(1, -76, 0.5, -11)
        keyBtn.BackgroundColor3 = Color3.fromRGB(36, 39, 52)
        keyBtn.Text = formatKeyName(defaultKeyCode)
        keyBtn.TextColor3 = Color3.fromRGB(150, 205, 255)
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 6)

        local keyStroke = Instance.new("UIStroke", keyBtn)
        keyStroke.Color = Color3.fromRGB(68, 82, 112)
        keyStroke.Thickness = 1

        local entry = {
            key = defaultKeyCode,
            onTrigger = onTrigger,
            updateVisual = nil
        }

        entry.updateVisual = function(listening)
            if listening then
                keyBtn.Text = "Press.."
                keyBtn.TextColor3 = Color3.fromRGB(255, 215, 90)
                keyStroke.Color = Color3.fromRGB(255, 190, 60)
                TweenService:Create(keyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(58, 46, 26)}):Play()
            else
                keyBtn.Text = formatKeyName(entry.key)
                keyBtn.TextColor3 = entry.key and Color3.fromRGB(140, 205, 255) or Color3.fromRGB(150, 158, 178)
                keyStroke.Color = entry.key and Color3.fromRGB(70, 125, 198) or Color3.fromRGB(60, 66, 86)
                TweenService:Create(keyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(36, 39, 52)}):Play()
            end
            if activeFuncListHud then
                activeFuncListHud.refresh()
            end
        end

        entry.updateVisual(false)
        table.insert(registeredKeybinds, entry)
        if activeFuncListHud then
            activeFuncListHud.attachKeybind(parent, name, entry)
        end

        keyBtn.Activated:Connect(function()
            if interactionState ~= "IDLE" then return end
            if activeBindingEntry == entry then
                activeBindingEntry = nil
                entry.updateVisual(false)
            else
                if activeBindingEntry then
                    activeBindingEntry.updateVisual(false)
                end
                activeBindingEntry = entry
                entry.updateVisual(true)
            end
        end)

        return row
    end

    createSubSelector = function(parent, name, options, defaultIndex, onSelect, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
        row.LayoutOrder = order or 1
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        attachSubItemDecor(row, Color3.fromRGB(255, 175, 75))

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -120, 1, 0)
        label.Position = UDim2.new(0, 20, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(205, 215, 235)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row

        local cycleBtn = Instance.new("TextButton")
        cycleBtn.Size = UDim2.new(0, 102, 0, 22)
        cycleBtn.Position = UDim2.new(1, -110, 0.5, -11)
        cycleBtn.BackgroundColor3 = Color3.fromRGB(36, 42, 60)
        cycleBtn.Font = Enum.Font.GothamBold
        cycleBtn.TextSize = 10
        cycleBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
        cycleBtn.AutoButtonColor = false
        cycleBtn.Parent = row
        Instance.new("UICorner", cycleBtn).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke", cycleBtn)
        stroke.Color = Color3.fromRGB(75, 85, 115)
        stroke.Thickness = 1

        local currentIndex = defaultIndex or 1
        local function updateText()
            local opt = options[currentIndex]
            cycleBtn.Text = type(opt) == "table" and opt.Name or tostring(opt)
        end
        updateText()

        cycleBtn.Activated:Connect(function()
            if interactionState ~= "IDLE" then return end
            currentIndex = (currentIndex % #options) + 1
            updateText()
            TweenService:Create(cycleBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(55, 68, 98)}):Play()
            task.delay(0.12, function()
                TweenService:Create(cycleBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(36, 42, 60)}):Play()
            end)
            local opt = options[currentIndex]
            local val = type(opt) == "table" and opt.Value or opt
            onSelect(val, currentIndex)
        end)

        return row
    end

    createToggleRow = function(parent, name, defaultState, onToggle, order, setupSubSettings)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -32, 0, 48)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        row.LayoutOrder = order or 1
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Color = Color3.fromRGB(55, 60, 80)
        rowStroke.Thickness = 1.2
        rowStroke.Transparency = 1

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.55, 0, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 3
        label.Parent = row

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 72, 0, 28)
        toggleBtn.Position = UDim2.new(1, -82, 0.5, -14)
        toggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(45, 180, 100) or Color3.fromRGB(60, 60, 75)
        toggleBtn.Text = defaultState and "ON" or "OFF"
        toggleBtn.TextColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 13
        toggleBtn.ZIndex = 4
        toggleBtn.Parent = row
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

        local hudItem = activeFuncListHud and activeFuncListHud.register(name) or nil
        if hudItem and defaultState then
            activeFuncListHud.setFuncEnabled(hudItem, true)
        end

        local isToggled = defaultState
        local function setToggleState(newState)
            isToggled = newState
            if isToggled then
                toggleBtn.Text = "ON"
                TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 180, 100), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            else
                toggleBtn.Text = "OFF"
                TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 75), TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
            end
            onToggle(isToggled)
            if activeFuncListHud and hudItem then
                activeFuncListHud.setFuncEnabled(hudItem, isToggled)
            end
        end

        toggleBtn.Activated:Connect(function()
            if interactionState ~= "IDLE" then return end
            setToggleState(not isToggled)
        end)

        local rowController = {
            frame = row,
            toggle = function()
                setToggleState(not isToggled)
            end,
            setState = setToggleState,
            getState = function() return isToggled end
        }

        if setupSubSettings then
            local rightClickCapture = Instance.new("TextButton")
            rightClickCapture.Name = "RightClickSettingsTrigger"
            rightClickCapture.Size = UDim2.new(1, 0, 1, 0)
            rightClickCapture.BackgroundTransparency = 1
            rightClickCapture.Text = ""
            rightClickCapture.AutoButtonColor = false
            rightClickCapture.ZIndex = 2
            rightClickCapture.Parent = row

            local gearBadge = Instance.new("TextButton")
            gearBadge.Name = "SettingsExpandBadge"
            gearBadge.Size = UDim2.new(0, 28, 0, 28)
            gearBadge.Position = UDim2.new(1, -116, 0.5, -14)
            gearBadge.BackgroundColor3 = Color3.fromRGB(36, 39, 52)
            gearBadge.Text = ""
            gearBadge.AutoButtonColor = false
            gearBadge.ZIndex = 4
            gearBadge.Parent = row
            Instance.new("UICorner", gearBadge).CornerRadius = UDim.new(0, 7)

            local gearBadgeStroke = Instance.new("UIStroke", gearBadge)
            gearBadgeStroke.Color = Color3.fromRGB(58, 66, 88)
            gearBadgeStroke.Thickness = 1

            local gearIcon = Instance.new("ImageLabel")
            gearIcon.Name = "LucideSettingsIcon"
            gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            gearIcon.Size = UDim2.new(0, 15, 0, 15)
            gearIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
            gearIcon.BackgroundTransparency = 1
            gearIcon.Image = "rbxassetid://10734950309"
            gearIcon.ImageColor3 = Color3.fromRGB(160, 175, 210)
            gearIcon.ZIndex = 5
            gearIcon.Parent = gearBadge

            local settingsPageFrame = Instance.new("ScrollingFrame")
            settingsPageFrame.Name = name .. "_SideSettings"
            settingsPageFrame.Size = UDim2.new(1, 0, 1, 0)
            settingsPageFrame.BackgroundTransparency = 1
            settingsPageFrame.BorderSizePixel = 0
            settingsPageFrame.ScrollBarThickness = 2
            settingsPageFrame.ScrollBarImageColor3 = Color3.fromRGB(75, 95, 135)
            settingsPageFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            settingsPageFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
            settingsPageFrame.Visible = false
            settingsPageFrame.Parent = sideContentHost

            local subLayout = Instance.new("UIListLayout")
            subLayout.Padding = UDim.new(0, 8)
            subLayout.SortOrder = Enum.SortOrder.LayoutOrder
            subLayout.Parent = settingsPageFrame

            local subPad = Instance.new("UIPadding")
            subPad.PaddingTop = UDim.new(0, 8)
            subPad.PaddingBottom = UDim.new(0, 12)
            subPad.PaddingLeft = UDim.new(0, 10)
            subPad.PaddingRight = UDim.new(0, 10)
            subPad.Parent = settingsPageFrame

            if activeFuncListHud and hudItem then
                activeFuncListHud.bindSettingsPage(settingsPageFrame, hudItem)
            end

            setupSubSettings(settingsPageFrame, rowController)

            local ownerEntry = {
                name = name,
                page = settingsPageFrame,
                setHighlight = function(active)
                    if active then
                        TweenService:Create(gearBadge, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            BackgroundColor3 = Color3.fromRGB(48, 115, 235)
                        }):Play()
                        TweenService:Create(gearBadgeStroke, TweenInfo.new(0.2), {
                            Color = Color3.fromRGB(95, 165, 255)
                        }):Play()
                        TweenService:Create(gearIcon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Rotation = 90,
                            ImageColor3 = Color3.fromRGB(255, 255, 255)
                        }):Play()
                        TweenService:Create(rowStroke, TweenInfo.new(0.2), {
                            Transparency = 0.2,
                            Color = Color3.fromRGB(65, 135, 245)
                        }):Play()
                    else
                        TweenService:Create(gearBadge, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            BackgroundColor3 = Color3.fromRGB(36, 39, 52)
                        }):Play()
                        TweenService:Create(gearBadgeStroke, TweenInfo.new(0.2), {
                            Color = Color3.fromRGB(58, 66, 88)
                        }):Play()
                        TweenService:Create(gearIcon, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Rotation = 0,
                            ImageColor3 = Color3.fromRGB(160, 175, 210)
                        }):Play()
                        TweenService:Create(rowStroke, TweenInfo.new(0.2), {
                            Transparency = 1
                        }):Play()
                    end
                end
            }

            local lastRightClickTick = 0
            local function onRightClickAttempt()
                local now = tick()
                if now - lastRightClickTick < 0.15 then return end
                lastRightClickTick = now
                openSideSettingsFor(ownerEntry)
            end

            rightClickCapture.MouseButton2Click:Connect(onRightClickAttempt)
            toggleBtn.MouseButton2Click:Connect(onRightClickAttempt)
            gearBadge.MouseButton2Click:Connect(onRightClickAttempt)
            gearBadge.Activated:Connect(onRightClickAttempt)

            row.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    onRightClickAttempt()
                end
            end)
        end

        return row, rowController
    end

    createSliderRow = function(parent, name, minVal, maxVal, defaultVal, onSliderChange, order)
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

    createActionButton = function(parent, name, btnText, onClick, order)
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
end -- [End 3D UI Component Builder Block]

-- ====================================================================
-- ScreenGui for Mobile Flight Controls
-- ====================================================================
do
    mobileGui = Instance.new("ScreenGui")
mobileGui.ResetOnSpawn = false
mobileGui.DisplayOrder = 996
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

local btnFlyUp = createMobileFlyBtn("FlyUp", "▲", 0)
local btnFlyDown = createMobileFlyBtn("FlyDown", "▼", 60)

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

    refreshFlyButtonsVisibility()
end

stopFly = function()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    if flyVelocity then flyVelocity:Destroy() end
    if flyAlign then flyAlign:Destroy() end
    if flyAttachment then flyAttachment:Destroy() end

    refreshFlyButtonsVisibility()
    mobileFlyUp = false
    mobileFlyDown = false
end

local espHighlights = {}

local function clearAllESP()
    for model, hl in pairs(espHighlights) do
        if hl and hl.Parent then
            pcall(function() hl:Destroy() end)
        end
    end
    table.clear(espHighlights)
end

updateESP = function()
    if not espEnabled then
        clearAllESP()
        return
    end

    local currentAliveModels = {}

    local function highlightTarget(model, isPlayer)
        if not model or not model.Parent then return end
        if model == player.Character then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        currentAliveModels[model] = true

        local fillColor = isPlayer and espPlayerColor or espNpcColor
        local hl = espHighlights[model]
        if not hl or hl.Parent ~= model then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Name = "ESP_Highlight"
            hl.Adornee = model
            hl.Parent = model
            espHighlights[model] = hl
        end

        hl.FillColor = fillColor
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = espFillTransparency
        hl.OutlineTransparency = 0
        hl.Enabled = true
    end

    -- 1. Highlight Players
    if espPlayerEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                highlightTarget(p.Character, true)
            end
        end
    end

    -- 2. Highlight Alive NPCs in Workspace
    if espNpcEnabled then
        local function scanForNPCs(parentObj, depth)
            if depth > 3 then return end
            for _, obj in ipairs(parentObj:GetChildren()) do
                if obj:IsA("Model") and obj ~= player.Character then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                        highlightTarget(obj, false)
                    else
                        if depth < 3 and not obj:FindFirstChildOfClass("Humanoid") then
                            scanForNPCs(obj, depth + 1)
                        end
                    end
                elseif obj:IsA("Folder") then
                    scanForNPCs(obj, depth + 1)
                end
            end
        end
        scanForNPCs(Workspace, 1)
    end

    -- Cleanup highlights for entities that are no longer valid or alive
    for model, hl in pairs(espHighlights) do
        if not currentAliveModels[model] then
            if hl then pcall(function() hl:Destroy() end) end
            espHighlights[model] = nil
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    if p.Character and espHighlights[p.Character] then
        pcall(function() espHighlights[p.Character]:Destroy() end)
        espHighlights[p.Character] = nil
    end
    if lockedTargetPart and lockedTargetPart.Parent == p.Character then
        local newTarget = getNearestTargetToCamera()
        if newTarget then
            lockedTargetPart = newTarget
            local targetPlayer = Players:GetPlayerFromCharacter(newTarget.Parent)
            updateCamlockButtonVisual(true, targetPlayer or newTarget.Parent.Name)
        else
            isTargetLocked = false
            lockedTargetPart = nil
            updateCamlockButtonVisual(false)
        end
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
-- Population of Menus (Right-Click Function Row to Open Inner Settings)
-- ====================================================================

-- [ TAB 1: PLAYER ]
createToggleRow(playerPage, "Walk Speed", false, function(v)
    speedEnabled = v
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = v and currentSpeed or defaultSpeed
    end
end, 1, function(sub, rowCtrl)
    createSubSlider(sub, "Speed Value", 16, 200, 16, function(v)
        currentSpeed = v
        if speedEnabled then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = currentSpeed end
        end
    end, 1)
    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 2)
end)

createToggleRow(playerPage, "Jump Power", false, function(v)
    jumpEnabled = v
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = v and currentJump or defaultJump
    end
end, 2, function(sub, rowCtrl)
    createSubSlider(sub, "Jump Value", 50, 300, 50, function(v)
        currentJump = v
        if jumpEnabled then
            local hum = getHumanoid()
            if hum then hum.UseJumpPower = true; hum.JumpPower = currentJump end
        end
    end, 1)
    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 2)
end)

createToggleRow(playerPage, "Bunny Hop (Bhop)", false, function(v)
    bhopEnabled = v
    bhopMomentum = currentSpeed
    setBhopScreenWidgets(v)
end, 3, function(sub, rowCtrl)
    createSubToggle(sub, "Show Auto-Jump Button", true, function(showBtn)
        setBhopScreenWidgets(bhopEnabled, showBtn, nil)
    end, 1)
    createMovePositionRow(sub, "Auto-Jump Button Pos", "autoJump", 2)
    createKeybindRow(sub, "Auto-Jump Keybind", nil, function()
        triggerAutoJumpAction()
    end, 3)
    createSubToggle(sub, "Show Speedometer HUD", true, function(showHud)
        setBhopScreenWidgets(bhopEnabled, nil, showHud)
    end, 4)
    createMovePositionRow(sub, "Speedometer HUD Pos", "speedHud", 5)
    createKeybindRow(sub, "Toggle Bhop Keybind", nil, function()
        rowCtrl.toggle()
    end, 6)
    createSubSlider(sub, "Max Bhop Speed", 50, 350, math.round(MAX_BHOP_SPEED), function(v)
        MAX_BHOP_SPEED = v
    end, 7)
    createSubSlider(sub, "Air Acceleration Rate (%)", 10, 200, math.round(STRAFE_BOOST_AIR * 100), function(v)
        STRAFE_BOOST_AIR = v / 100
    end, 8)
    createSubSlider(sub, "Jump Boost Power", 1, 25, math.round(JUMP_INITIAL_BOOST), function(v)
        JUMP_INITIAL_BOOST = v
    end, 9)
    createSubSlider(sub, "Max Straight Speed", 20, 150, math.round(MAX_STRAIGHT_SPEED), function(v)
        MAX_STRAIGHT_SPEED = v
    end, 10)
    createSubSlider(sub, "Straight Bleed Rate", 1, 30, math.round(STRAIGHT_BLEED_RATE), function(v)
        STRAIGHT_BLEED_RATE = v
    end, 11)
end)

createToggleRow(playerPage, "Fly Mode (Mobile/PC)", false, function(v)
    flyEnabled = v
    if v then startFly() else stopFly() end
end, 4, function(sub, rowCtrl)
    createSubSlider(sub, "Fly Speed", 10, 200, 50, function(v)
        flySpeed = v
    end, 1)
    createSubToggle(sub, "Show Up/Down Buttons", true, function(showFly)
        refreshFlyButtonsVisibility(showFly)
    end, 2)
    createMovePositionRow(sub, "Up/Down Buttons Pos", "flyBtns", 3)
    createKeybindRow(sub, "Toggle Fly Keybind", nil, function()
        rowCtrl.toggle()
    end, 4)
end)

createToggleRow(playerPage, "Noclip (Walk Through)", false, function(v)
    noclipEnabled = v
end, 5, function(sub, rowCtrl)
    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 1)
end)

createToggleRow(playerPage, "Infinite Jump", false, function(v)
    infJumpEnabled = v
end, 6, function(sub, rowCtrl)
    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 1)
end)

-- [ TAB 2: VISUALS & COMBAT ]
createToggleRow(visualsPage, "Camlock (Aim Lock)", false, function(v)
    camlockEnabled = v
    if not v then
        isTargetLocked = false
        lockedTargetPart = nil
        updateCamlockButtonVisual(false)
    end
    setCamlockButtonVisible(v)
    if updateCamlockFovVisual then updateCamlockFovVisual() end
end, 1, function(sub, rowCtrl)
    createSubToggle(sub, "Show Lock Button", true, function(showBtn)
        setCamlockButtonVisible(camlockEnabled, showBtn)
    end, 1)
    createMovePositionRow(sub, "Lock Button Position", "camlock", 2)
    createKeybindRow(sub, "Lock Target Keybind", Enum.KeyCode.Q, function()
        triggerCamlockAction()
    end, 3)
    createKeybindRow(sub, "Toggle Camlock Keybind", nil, function()
        rowCtrl.toggle()
    end, 4)
    createSubSelector(sub, "Target Mode", {
        { Name = "All Targets", Value = "All" },
        { Name = "Players Only", Value = "Players" },
        { Name = "Alive NPCs", Value = "NPCs" },
    }, 1, function(val)
        camlockTargetMode = val
        if isTargetLocked and lockedTargetPart then
            local isPlayer = Players:GetPlayerFromCharacter(lockedTargetPart.Parent) ~= nil
            if (val == "Players" and not isPlayer) or (val == "NPCs" and isPlayer) then
                isTargetLocked = false
                lockedTargetPart = nil
                updateCamlockButtonVisual(false)
            end
        end
    end, 5)
    createSubSelector(sub, "Lock Angle (FOV)", {
        { Name = "180 Deg (Front)", Value = "180" },
        { Name = "360 Deg (All-Around)", Value = "360" },
    }, 1, function(val)
        camlockFovMode = val
    end, 6)
    createSubSlider(sub, "Aim Smoothness (%)", 5, 100, 25, function(v)
        CAMLOCK_SMOOTHNESS = math.clamp(v / 100, 0.05, 1)
    end, 7)
    createSubSlider(sub, "Max Lock Distance", 50, 600, 250, function(v)
        CAMLOCK_MAX_DIST = v
    end, 8)
    createSubToggle(sub, "Show FOV Circle", camlockShowFovCircle, function(val)
        camlockShowFovCircle = val
        if updateCamlockFovVisual then updateCamlockFovVisual() end
    end, 9)
    createSubToggle(sub, "Use FOV Circle Limit", camlockUseFovLimit, function(val)
        camlockUseFovLimit = val
    end, 10)
    createSubSlider(sub, "FOV Circle Radius", 30, 450, camlockFovRadius, function(v)
        camlockFovRadius = v
        if updateCamlockFovVisual then updateCamlockFovVisual() end
    end, 11)
    createSubSelector(sub, "FOV Circle Color", {
        { Name = "Cyan", Value = Color3.fromRGB(40, 230, 255) },
        { Name = "Blue", Value = Color3.fromRGB(60, 160, 255) },
        { Name = "Red", Value = Color3.fromRGB(255, 60, 60) },
        { Name = "Green", Value = Color3.fromRGB(50, 225, 90) },
        { Name = "Yellow", Value = Color3.fromRGB(255, 215, 0) },
        { Name = "Purple", Value = Color3.fromRGB(180, 80, 255) },
        { Name = "White", Value = Color3.fromRGB(255, 255, 255) },
    }, 1, function(col)
        camlockFovColor = col
        if updateCamlockFovVisual then updateCamlockFovVisual() end
    end, 12)
end)

createToggleRow(visualsPage, "ESP (Chams)", false, function(v)
    espEnabled = v
    updateESP()
end, 2, function(sub, rowCtrl)
    local espColorOptions = {
        { Name = "Red", Value = Color3.fromRGB(255, 60, 60) },
        { Name = "Green", Value = Color3.fromRGB(50, 225, 90) },
        { Name = "Blue", Value = Color3.fromRGB(60, 160, 255) },
        { Name = "Yellow", Value = Color3.fromRGB(255, 215, 0) },
        { Name = "Purple", Value = Color3.fromRGB(180, 80, 255) },
        { Name = "Orange", Value = Color3.fromRGB(255, 140, 30) },
        { Name = "Cyan", Value = Color3.fromRGB(40, 230, 255) },
        { Name = "White", Value = Color3.fromRGB(255, 255, 255) },
    }

    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 1)
    createSubSelector(sub, "Player Color", espColorOptions, 1, function(col)
        espPlayerColor = col
        updateESP()
    end, 2)
    createSubSelector(sub, "NPC Color", espColorOptions, 2, function(col)
        espNpcColor = col
        updateESP()
    end, 3)
    createSubToggle(sub, "Show Players", true, function(v)
        espPlayerEnabled = v
        updateESP()
    end, 4)
    createSubToggle(sub, "Show Alive NPCs", true, function(v)
        espNpcEnabled = v
        updateESP()
    end, 5)
    createSubSlider(sub, "Fill Transparency (%)", 0, 100, 50, function(v)
        espFillTransparency = v / 100
        updateESP()
    end, 6)
end)

createToggleRow(visualsPage, "Fullbright", false, function(v)
    fullbrightEnabled = v
    applyFullbright(v)
end, 3, function(sub, rowCtrl)
    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 1)
end)

-- [ TAB 3: SETTINGS & UTILITY ]
createToggleRow(settingsPage, "Active Functions List", true, function(v)
    if activeFuncListHud then
        activeFuncListHud.setHudVisible(v)
    end
end, 1, function(sub, rowCtrl)
    createMovePositionRow(sub, "Function List Position", "funcList", 1)
    createKeybindRow(sub, "Toggle List Keybind", nil, function()
        rowCtrl.toggle()
    end, 2)
end)

createToggleRow(settingsPage, "Anti-AFK (20m Kick Guard)", false, function(v)
    antiAfkEnabled = v
end, 2, function(sub, rowCtrl)
    createKeybindRow(sub, "Toggle Keybind", nil, function()
        rowCtrl.toggle()
    end, 1)
end)

createActionButton(settingsPage, "Server Rejoin", "Rejoin", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
end, 3)

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
wardrobeSurfaceGui.AlwaysOnTop = false
wardrobeSurfaceGui.ResetOnSpawn = false
wardrobeSurfaceGui.Enabled = false
wardrobeSurfaceGui.Parent = targetGuiParent

wardrobeBackSurfaceGui = Instance.new("SurfaceGui")
wardrobeBackSurfaceGui.Name = "SpatialWardrobeUI_Backplate"
wardrobeBackSurfaceGui.Adornee = wardrobePart
wardrobeBackSurfaceGui.Face = Enum.NormalId.Back
wardrobeBackSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
wardrobeBackSurfaceGui.PixelsPerStud = 100
wardrobeBackSurfaceGui.AlwaysOnTop = false
wardrobeBackSurfaceGui.ResetOnSpawn = false
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

local wardrobeBackBtn = Instance.new("TextButton")
wardrobeBackBtn.Name = "WardrobeBackButton"
wardrobeBackBtn.Size = UDim2.new(0, 28, 0, 28)
wardrobeBackBtn.Position = UDim2.new(0, 12, 0, 8)
wardrobeBackBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
wardrobeBackBtn.Text = ""
wardrobeBackBtn.AutoButtonColor = false
wardrobeBackBtn.Parent = wardrobeMainWindow
Instance.new("UICorner", wardrobeBackBtn).CornerRadius = UDim.new(0, 7)

local wardrobeBackStroke = Instance.new("UIStroke", wardrobeBackBtn)
wardrobeBackStroke.Color = Color3.fromRGB(55, 62, 82)
wardrobeBackStroke.Thickness = 1

local wardrobeBackIcon = Instance.new("ImageLabel")
wardrobeBackIcon.Size = UDim2.new(0, 16, 0, 16)
wardrobeBackIcon.AnchorPoint = Vector2.new(0.5, 0.5)
wardrobeBackIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
wardrobeBackIcon.BackgroundTransparency = 1
wardrobeBackIcon.Image = "rbxassetid://10709791437"
wardrobeBackIcon.Rotation = 180
wardrobeBackIcon.ImageColor3 = Color3.fromRGB(205, 220, 245)
wardrobeBackIcon.Parent = wardrobeBackBtn

wardrobeBackBtn.MouseEnter:Connect(function()
    TweenService:Create(wardrobeBackBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(44, 52, 72)}):Play()
    TweenService:Create(wardrobeBackStroke, TweenInfo.new(0.18), {Color = Color3.fromRGB(88, 166, 255)}):Play()
    TweenService:Create(wardrobeBackIcon, TweenInfo.new(0.18), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)

wardrobeBackBtn.MouseLeave:Connect(function()
    TweenService:Create(wardrobeBackBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(30, 34, 46)}):Play()
    TweenService:Create(wardrobeBackStroke, TweenInfo.new(0.18), {Color = Color3.fromRGB(55, 62, 82)}):Play()
    TweenService:Create(wardrobeBackIcon, TweenInfo.new(0.18), {ImageColor3 = Color3.fromRGB(205, 220, 245)}):Play()
end)

wardrobeCloseBtn = wardrobeBackBtn

local wardrobeTitle = Instance.new("TextLabel")
wardrobeTitle.Size = UDim2.new(1, -55, 0, 24)
wardrobeTitle.Position = UDim2.new(0, 48, 0, 8)
wardrobeTitle.BackgroundTransparency = 1
wardrobeTitle.Text = "Character Cosmetics"
wardrobeTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
wardrobeTitle.TextSize = 15
wardrobeTitle.Font = Enum.Font.GothamBold
wardrobeTitle.TextXAlignment = Enum.TextXAlignment.Left
wardrobeTitle.Parent = wardrobeMainWindow

local wardrobeSubTitle = Instance.new("TextLabel")
wardrobeSubTitle.Size = UDim2.new(1, -55, 0, 14)
wardrobeSubTitle.Position = UDim2.new(0, 48, 0, 29)
wardrobeSubTitle.BackgroundTransparency = 1
wardrobeSubTitle.Text = "@" .. player.DisplayName .. " // LOOK & VISUALS"
wardrobeSubTitle.TextColor3 = Color3.fromRGB(110, 125, 150)
wardrobeSubTitle.TextSize = 10
wardrobeSubTitle.Font = Enum.Font.GothamBold
wardrobeSubTitle.TextXAlignment = Enum.TextXAlignment.Left
wardrobeSubTitle.Parent = wardrobeMainWindow

wardrobePage = Instance.new("ScrollingFrame")
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
-- Grab Bar Area (Bottom)
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

isHoveringWardrobeUI = false
local function trackWardrobeHover(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then return end
    guiObj.MouseEnter:Connect(function()
        isHoveringWardrobeUI = true
    end)
    guiObj.MouseLeave:Connect(function()
        isHoveringWardrobeUI = false
    end)
end

trackWardrobeHover(wardrobeMainWindow)
trackWardrobeHover(wardrobePage)
trackWardrobeHover(wardrobeGrabBarContainer)
end -- [End Wardrobe 3D UI Setup Block]

-- ====================================================================
-- Character Cosmetic Features Logic
-- ====================================================================
do
freezeCharacter = false
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
local wardrobeToggleControllers = {}

local function addWardrobeToggle(name, callback, order)
    local _, ctrl = createToggleRow(wardrobePage, name, false, callback, order)
    table.insert(wardrobeToggleControllers, ctrl)
end

addWardrobeToggle("Freeze Pose (Mannequin)", function(v)
    setFreezePose(v)
end, 1)

addWardrobeToggle("Rainbow Chroma Skin", function(v)
    setRainbowSkin(v)
end, 2)

addWardrobeToggle("Ghost Mode (50% Alpha)", function(v)
    setGhostMode(v)
end, 3)

addWardrobeToggle("Forcefield Shield", function(v)
    setForcefield(v)
end, 4)

addWardrobeToggle("Neon Glow Body", function(v)
    setNeonGlow(v)
end, 5)

addWardrobeToggle("Sparkles & Fire Aura", function(v)
    setAura(v)
end, 6)

createActionButton(wardrobePage, "Accessories (Hats)", "Toggle", function()
    toggleAccessories()
end, 7)

createActionButton(wardrobePage, "Reset Look & Effects", "Reset", function()
    for _, ctrl in ipairs(wardrobeToggleControllers) do
        if ctrl and ctrl.getState and ctrl.getState() then
            ctrl.setState(false)
        end
    end
    restoreCharacterAppearance()
end, 8)

-- ====================================================================
-- Continuous Track Tab Animation Logic
-- ====================================================================
local allTabIcons = {}

local function switchTab(newIndex, targetCenterY, icon, tabName)
    if isAnimating or currentTabIndex == newIndex then return end
    isAnimating = true

    if isSideSettingsOpen and closeSideSettingsWindow then
        closeSideSettingsWindow(false)
    end

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

    currentTabIndex = newIndex
    local trackTween = TweenService:Create(pagesTrack, TweenInfo.new(0.48, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
        Position = UDim2.new(-(newIndex - 1), 0, 0, 0)
    })
    trackTween:Play()

    trackTween.Completed:Connect(function()
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

-- Player Profile Button (Avatar Headshot in Sidebar)
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
end -- [End Character Cosmetic Features Block]

-- ====================================================================
-- Resize Corner Handle & Drag Handlers
-- ====================================================================
do
-- Resize Corner Handle
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

line1 = createHandleLine(16, 18, 24)
line2 = createHandleLine(9, 25, 31)

-- Grab Bar Area (Bottom)
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
    local camCF = camera.CFrame
    local rightVec = camCF.RightVector
    local upVec = camCF.UpVector
    local distance = (wardrobePart.Position - camCF.Position).Magnitude
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
    local totalW = currentPartWidth + (isSideSettingsOpen and SIDE_PANEL_STUDS or 0)
    uiPart.Size = Vector3.new(totalW, currentPartHeight, 0.05)

    local mainTotalPx = math.round(currentPartWidth * 100)
    mainFrame.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
    backMainWindow.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
    backMainWindow.Position = UDim2.new(1, -mainTotalPx, 0, 0)
    if isSideSettingsOpen and sideSettingsWindow then
        sideSettingsWindow.Position = UDim2.new(0, mainTotalPx + 8, 0, 0)
    end
    pagesTrack.Position = UDim2.new(-((currentTabIndex or 1) - 1), 0, 0, 0)
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
end -- [End Drag / Resize Handlers Block]

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
-- Hide & Summon Animations (3D Spatial Holographic Spring System)
-- ====================================================================
local function ensureUIScale(guiObj)
    local sc = guiObj:FindFirstChildOfClass("UIScale")
    if not sc then
        sc = Instance.new("UIScale")
        sc.Parent = guiObj
    end
    return sc
end

local function cascadePageRows(pageFrame, baseDelay)
    if not pageFrame then return end
    local rows = {}
    for _, child in ipairs(pageFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            table.insert(rows, child)
        end
    end
    table.sort(rows, function(a, b)
        return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
    end)
    for idx, row in ipairs(rows) do
        local sc = ensureUIScale(row)
        sc.Scale = 0.88
        task.delay((baseDelay or 0.08) + ((idx - 1) * 0.032), function()
            if row and row.Parent then
                TweenService:Create(sc, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Scale = 1
                }):Play()
            end
        end)
    end
end

hideUIWithAnimation = function()
    if not isUIVisible or isAnimating then return end
    isAnimating = true

    if isWardrobeVisible then
        hideWardrobeWithAnimation()
    end

    if closeSideSettingsWindow then
        closeSideSettingsWindow(true)
    end

    backSurfaceGui.Enabled = false

    local mScale = ensureUIScale(mainFrame)
    local sScale = ensureUIScale(sidebar)
    local gScale = ensureUIScale(grabBarContainer)
    local mStroke = mainFrame:FindFirstChildOfClass("UIStroke")
    if mStroke then
        TweenService:Create(mStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(95, 185, 255)
        }):Play()
    end

    -- Layered fold-in without squishing MainWindow width
    TweenService:Create(grabBarContainer, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, 1, -12)
    }):Play()
    TweenService:Create(gScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Scale = 0.65
    }):Play()

    TweenService:Create(sidebar, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 32, 0, 12)
    }):Play()
    TweenService:Create(sScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Scale = 0.82
    }):Play()

    TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 60, 0, 22)
    }):Play()
    TweenService:Create(mScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Scale = 0.8
    }):Play()

    local pushbackTarget = uiPart.CFrame * CFrame.new(0, 0.25, -1.15) * CFrame.Angles(math.rad(-16), math.rad(6), math.rad(-2))

    local partTween = TweenService:Create(uiPart, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = Vector3.new(currentPartWidth * 0.45, currentPartHeight * 0.45, 0.05),
        CFrame = pushbackTarget
    })
    local fadeTween = TweenService:Create(container, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        GroupTransparency = 1
    })

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

    if closeSideSettingsWindow then
        closeSideSettingsWindow(true)
    end

    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not root then 
        isAnimating = false
        return 
    end

    performZoomInAndAlign()

    local finalSpawnPos = calculateCameraFrontPosition()
    local finalCFrame = getFacingCFrame(finalSpawnPos)

    local mainTotalPx = math.round(currentPartWidth * 100)
    mainFrame.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
    backMainWindow.Size = UDim2.new(0, mainTotalPx - 60, 1, -55)
    backMainWindow.Position = UDim2.new(1, -mainTotalPx, 0, 0)

    local mScale = ensureUIScale(mainFrame)
    local sScale = ensureUIScale(sidebar)
    local gScale = ensureUIScale(grabBarContainer)
    local mStroke = mainFrame:FindFirstChildOfClass("UIStroke")

    uiPart.Size = Vector3.new(currentPartWidth * 0.52, currentPartHeight * 0.52, 0.05)
    uiPart.CFrame = finalCFrame * CFrame.new(0, -0.55, -0.65) * CFrame.Angles(math.rad(18), math.rad(-8), math.rad(2.5))

    container.GroupTransparency = 1
    mainFrame.Position = UDim2.new(0, 60, 0, 26)
    mScale.Scale = 0.82

    sidebar.Position = UDim2.new(0, 32, 0, 12)
    sScale.Scale = 0.82

    grabBarContainer.Position = UDim2.new(0, 0, 1, -12)
    gScale.Scale = 0.65

    if mStroke then
        mStroke.Color = Color3.fromRGB(95, 190, 255)
    end

    local activeIdx = currentTabIndex or 1
    pagesTrack.Position = UDim2.new(-(activeIdx - 1), 0, 0, 0)
    local activeCenterY = 12 + ((activeIdx - 1) * 46) + 18
    tabIndicator.Position = UDim2.new(0.5, 0, 0, activeCenterY)

    surfaceGui.Enabled = true
    backSurfaceGui.Enabled = true
    isUIVisible = true
    updateToggleBtnState(true)

    local tabTitles = {
        [1] = "Player Controls",
        [2] = "Visual Mod Menu",
        [3] = "Settings & Utility"
    }
    typewriteTitle(tabTitles[activeIdx] or "Player Controls")

    local activePages = {
        [1] = playerPage,
        [2] = visualsPage,
        [3] = settingsPage
    }
    cascadePageRows(activePages[activeIdx], 0.08)

    local partTween = TweenService:Create(uiPart, TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(currentPartWidth, currentPartHeight, 0.05),
        CFrame = finalCFrame
    })
    local containerFade = TweenService:Create(container, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        GroupTransparency = 0
    })

    partTween:Play()
    containerFade:Play()

    TweenService:Create(mainFrame, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 60, 0, 0)
    }):Play()
    TweenService:Create(mScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1
    }):Play()

    if mStroke then
        TweenService:Create(mStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(65, 65, 80)
        }):Play()
    end

    task.delay(0.08, function()
        TweenService:Create(sidebar, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        TweenService:Create(sScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = 1
        }):Play()
    end)

    task.delay(0.16, function()
        TweenService:Create(gScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = 1
        }):Play()
        local barTween = TweenService:Create(grabBarContainer, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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
do
    local WARDROBE_CAM_BIND = "SpatialUI_WardrobeCameraRender"
    local orbitYaw = 0
    local orbitPitch = 4
    local orbitRadius = 6.8
    local orbitLateralOffset = 1.05
    local isOrbitDragging = false
    local isOrbitActive = false
    local lastDragInputPos = nil
    local activeWardrobeCamCF = nil
    local currentCharFocus = Vector3.zero
    local lockedCharCFrame = nil
    local savedAutoRotate = true
    local wardrobeRelCF = nil
    local lastKnownWardrobeWorldCF = nil
    local orbitInputBeganConn = nil
    local orbitInputEndedConn = nil
    local orbitInputChangedConn = nil

    local function forceCharacterVisible(char)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = 0
            end
        end
    end

    local function computeOrbitCamCFrame(focusPos, yaw, pitch, radius, lateral)
        local rotCF = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(pitch), 0, 0)
        local offsetPos = rotCF:VectorToWorldSpace(Vector3.new(0, 0.35, radius))
        local centerCamCF = CFrame.lookAt(focusPos + offsetPos, focusPos + Vector3.new(0, 0.15, 0))
        return centerCamCF * CFrame.new(-lateral, 0, 0)
    end

    local function startWardrobeCameraBind()
        pcall(function()
            RunService:UnbindFromRenderStep(WARDROBE_CAM_BIND)
        end)
        RunService:BindToRenderStep(WARDROBE_CAM_BIND, Enum.RenderPriority.Camera.Value + 2, function(dt)
            if not isWardrobeMode then return end

            -- Prevent Roblox CameraModule from locking cursor or forcing ShiftLock/FirstPerson rotation
            camera.CameraType = Enum.CameraType.Scriptable
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
            pcall(function()
                UserSettings().GameSettings.RotationType = Enum.RotationType.MovementRelative
            end)

            local char = player.Character
            forceCharacterVisible(char)

            local root = getRootPart()
            local hum = getHumanoid()
            if hum then
                hum.AutoRotate = false
            end
            if root and lockedCharCFrame then
                root.CFrame = lockedCharCFrame
            end

            if isOrbitActive and activeWardrobeCamCF then
                if root then
                    currentCharFocus = root.Position + Vector3.new(0, 0.55, 0)
                end
                local targetCF = computeOrbitCamCFrame(currentCharFocus, orbitYaw, orbitPitch, orbitRadius, orbitLateralOffset)
                activeWardrobeCamCF = activeWardrobeCamCF:Lerp(targetCF, math.clamp(dt * 14, 0.15, 0.45))
            end

            if activeWardrobeCamCF then
                camera.CFrame = activeWardrobeCamCF

                if isWardrobeVisible and not isWardrobeAnimating and wardrobePart then
                    if interactionState == "DRAGGING_WARDROBE" then
                        wardrobeRelCF = activeWardrobeCamCF:ToObjectSpace(wardrobePart.CFrame)
                        lastKnownWardrobeWorldCF = wardrobePart.CFrame
                    elseif wardrobeRelCF then
                        local desiredWorldCF = activeWardrobeCamCF:ToWorldSpace(wardrobeRelCF)
                        wardrobePart.CFrame = CFrame.lookAt(desiredWorldCF.Position, activeWardrobeCamCF.Position)
                    end
                end
            end
        end)
    end

    cleanupOrbitController = function()
        isOrbitActive = false
        pcall(function()
            RunService:UnbindFromRenderStep(WARDROBE_CAM_BIND)
        end)
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
        currentCharFocus = charFocus
        orbitYaw = baseYaw
        orbitPitch = 4
        orbitRadius = 6.8
        orbitLateralOffset = 1.05
        isOrbitActive = true

        if orbitInputBeganConn then orbitInputBeganConn:Disconnect() end
        if orbitInputEndedConn then orbitInputEndedConn:Disconnect() end
        if orbitInputChangedConn then orbitInputChangedConn:Disconnect() end

        local function isMousePointingAtWardrobe()
            if isHoveringWardrobeUI then return true end
            if not isWardrobeVisible or not wardrobePart or wardrobePart.Parent == nil then return false end
            local mousePos = UserInputService:GetMouseLocation()
            local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Include
            rayParams.FilterDescendantsInstances = { wardrobePart }
            local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 60, rayParams)
            return result ~= nil and result.Instance == wardrobePart
        end

        orbitInputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if interactionState ~= "IDLE" then return end
            -- If mouse is clicking over the Wardrobe UI, do not initiate orbit drag
            if isMousePointingAtWardrobe() and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                return
            end

            -- Note: MouseButton2 has gameProcessed=true because Roblox CameraModule binds RightClick, so allow MouseButton2 regardless
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                isOrbitDragging = true
                lastDragInputPos = input.Position
            elseif not gameProcessed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
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
            if interactionState ~= "IDLE" then
                isOrbitDragging = false
                lastDragInputPos = nil
                return
            end
            if isOrbitDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local deltaX = 0
                local deltaY = 0
                if lastDragInputPos then
                    local posDelta = input.Position - lastDragInputPos
                    deltaX = posDelta.X
                    deltaY = posDelta.Y
                end
                if math.abs(deltaX) < 0.001 and math.abs(deltaY) < 0.001 and input.Delta then
                    deltaX = input.Delta.X
                    deltaY = input.Delta.Y
                end
                orbitYaw = orbitYaw - (deltaX * 0.0085)
                orbitPitch = math.clamp(orbitPitch - (deltaY * 0.35), -45, 55)
                lastDragInputPos = input.Position
            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                -- Do NOT zoom camera if mouse is over wardrobe UI
                if not isMousePointingAtWardrobe() then
                    orbitRadius = math.clamp(orbitRadius - (input.Position.Z * 0.75), 3.2, 12.0)
                end
            end
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

        -- 1. Save previous camera state and force CameraModule out of First-Person (minZoom > 0.5)
        previousCameraType = camera.CameraType
        previousCameraCFrame = camera.CFrame
        activeWardrobeCamCF = camera.CFrame
        lockedCharCFrame = root.CFrame
        savedAutoRotate = hum.AutoRotate
        hum.AutoRotate = false

        player.CameraMaxZoomDistance = 128
        player.CameraMinZoomDistance = 7.0
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        pcall(function()
            UserSettings().GameSettings.RotationType = Enum.RotationType.MovementRelative
        end)
        camera.CameraType = Enum.CameraType.Scriptable
        forceCharacterVisible(char)

        -- Start post-camera RenderStep bind so CameraModule cannot snap back to first person or ShiftLock
        startWardrobeCameraBind()

        -- 2. Anchor character position cleanly
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true

        -- 3. Smoothly fold & hide the Main 3D UI while camera starts zooming out
        wasMainUIVisibleBeforeWardrobe = isUIVisible
        if isUIVisible then
            if closeSideSettingsWindow then
                closeSideSettingsWindow(true)
            end
            isUIVisible = false
            backSurfaceGui.Enabled = false
            if updateToggleBtnState then updateToggleBtnState(false) end

            local mScale = ensureUIScale(mainFrame)
            TweenService:Create(mScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Scale = 0.82
            }):Play()

            local pushbackTarget = uiPart.CFrame * CFrame.new(0, 0.25, -1.1) * CFrame.Angles(math.rad(-14), 0, 0)
            TweenService:Create(uiPart, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = Vector3.new(currentPartWidth * 0.45, currentPartHeight * 0.45, 0.05),
                CFrame = pushbackTarget
            }):Play()
            TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                GroupTransparency = 1
            }):Play()

            task.delay(0.22, function()
                if not isUIVisible then
                    surfaceGui.Enabled = false
                    uiPart.Position = Vector3.new(0, 9999, 0)
                end
            end)
        end

        -- 4. Calculate front-facing camera position looking at our character's face/front
        local charPos = root.Position
        local charLook = root.CFrame.LookVector
        local charFocus = charPos + Vector3.new(0, 0.55, 0)
        local baseYaw = math.atan2(charLook.X, charLook.Z)

        orbitYaw = baseYaw
        orbitPitch = 4
        orbitRadius = 6.8
        orbitLateralOffset = 1.05

        local startCamCFrame = activeWardrobeCamCF
        local goalCamCFrame = computeOrbitCamCFrame(charFocus, orbitYaw, orbitPitch, orbitRadius, orbitLateralOffset)

        -- 5. Smooth cinematic zoom-out & sweep to front of character
        local enterDuration = 0.58
        local startTick = tick()

        while (tick() - startTick < enterDuration) do
            local alpha = math.clamp((tick() - startTick) / enterDuration, 0, 1)
            local smoothAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            activeWardrobeCamCF = startCamCFrame:Lerp(goalCamCFrame, smoothAlpha)
            RunService.RenderStepped:Wait()
        end
        activeWardrobeCamCF = goalCamCFrame

        -- 6. Position Wardrobe 3D UI on the left side facing the camera directly
        local uiDist = 4.6
        local uiLeft = 2.05
        local uiElev = -0.05

        local wardrobeSpawnPos = goalCamCFrame.Position + (goalCamCFrame.LookVector * uiDist) - (goalCamCFrame.RightVector * uiLeft) + (goalCamCFrame.UpVector * uiElev)
        local finalCFrame = CFrame.lookAt(wardrobeSpawnPos, goalCamCFrame.Position)
        wardrobeRelCF = goalCamCFrame:ToObjectSpace(finalCFrame)

        local wScale = ensureUIScale(wardrobeMainWindow)
        local wgScale = ensureUIScale(wardrobeGrabBarContainer)
        local wStroke = wardrobeMainWindow:FindFirstChildOfClass("UIStroke")

        wardrobePart.Size = Vector3.new(2.2, 1.9, 0.05)
        wardrobePart.CFrame = finalCFrame * CFrame.new(-0.35, -0.45, -0.55) * CFrame.Angles(math.rad(16), math.rad(12), math.rad(-3))
        wardrobeContainer.GroupTransparency = 1
        wardrobeMainWindow.Size = UDim2.new(1, 0, 1, -55)
        wardrobeMainWindow.Position = UDim2.new(0, 0, 0, 22)
        wScale.Scale = 0.82

        wardrobeGrabBarContainer.Position = UDim2.new(0, 0, 1, -12)
        wgScale.Scale = 0.65

        if wStroke then
            wStroke.Color = Color3.fromRGB(95, 190, 255)
        end

        wardrobeSurfaceGui.AlwaysOnTop = false
        wardrobeSurfaceGui.Enabled = true
        wardrobeBackSurfaceGui.Enabled = true
        isWardrobeVisible = true

        local wScroll = wardrobeMainWindow:FindFirstChildOfClass("ScrollingFrame")
        cascadePageRows(wScroll, 0.06)

        profileStroke.Color = Color3.fromRGB(50, 140, 255)
        TweenService:Create(profileBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(35, 45, 65)}):Play()

        local partTween = TweenService:Create(wardrobePart, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = Vector3.new(4.2, 3.6, 0.05),
            CFrame = finalCFrame
        })
        local containerFade = TweenService:Create(wardrobeContainer, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            GroupTransparency = 0
        })

        partTween:Play()
        containerFade:Play()

        TweenService:Create(wardrobeMainWindow, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        TweenService:Create(wScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = 1
        }):Play()

        if wStroke then
            TweenService:Create(wStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Color = Color3.fromRGB(65, 65, 80)
            }):Play()
        end

        -- 7. Enable 360-degree orbit inspection controller
        setupOrbitController(charFocus, baseYaw)

        task.delay(0.18, function()
            TweenService:Create(wgScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Scale = 1
            }):Play()
            local barTween = TweenService:Create(wardrobeGrabBarContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 1, -50)
            })
            barTween:Play()
            barTween.Completed:Connect(function()
                isWardrobeAnimating = false
            end)
        end)
        if updateCamlockFovVisual then updateCamlockFovVisual() end
    end

    hideWardrobeWithAnimation = function()
        if not isWardrobeVisible or isWardrobeAnimating then return end
        isWardrobeAnimating = true
        isOrbitActive = false

        wardrobeBackSurfaceGui.Enabled = false
        profileStroke.Color = Color3.fromRGB(65, 65, 85)
        TweenService:Create(profileBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(24, 24, 32)}):Play()

        local wScale = ensureUIScale(wardrobeMainWindow)
        local wgScale = ensureUIScale(wardrobeGrabBarContainer)

        TweenService:Create(wardrobeGrabBarContainer, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 0, 1, -12)
        }):Play()
        TweenService:Create(wgScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Scale = 0.65
        }):Play()

        TweenService:Create(wardrobeMainWindow, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 0, 0, 20)
        }):Play()
        TweenService:Create(wScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Scale = 0.8
        }):Play()

        local pushbackTarget = wardrobePart.CFrame * CFrame.new(-0.25, 0.25, -1.1) * CFrame.Angles(math.rad(-14), math.rad(10), 0)
        local partTween = TweenService:Create(wardrobePart, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = Vector3.new(2.0, 1.7, 0.05),
            CFrame = pushbackTarget
        })
        local fadeTween = TweenService:Create(wardrobeContainer, TweenInfo.new(0.23, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            GroupTransparency = 1
        })

        partTween:Play()
        fadeTween:Play()
        fadeTween.Completed:Wait()

        wardrobeSurfaceGui.Enabled = false
        wardrobePart.Position = Vector3.new(0, 9999, 0)
        isWardrobeVisible = false

        -- Smooth cinematic camera return directly into First-Person view
        local root = getRootPart()
        local hum = getHumanoid()
        local head = getHead()
        local returnDuration = 0.38
        local startCam = activeWardrobeCamCF or camera.CFrame
        local charForward = (root and root.CFrame.LookVector) or camera.CFrame.LookVector
        local headPos = (head and head.Position) or (root and (root.Position + Vector3.new(0, 1.5, 0))) or camera.CFrame.Position
        local goalCam = CFrame.lookAt(headPos, headPos + (charForward * 10))

        local startTick = tick()
        while (tick() - startTick < returnDuration) do
            local alpha = math.clamp((tick() - startTick) / returnDuration, 0, 1)
            local smoothAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            activeWardrobeCamCF = startCam:Lerp(goalCam, smoothAlpha)
            RunService.RenderStepped:Wait()
        end
        activeWardrobeCamCF = goalCam

        -- Cleanup custom camera bind and restore first person camera
        cleanupOrbitController()
        activeWardrobeCamCF = nil
        lockedCharCFrame = nil
        if hum then
            hum.AutoRotate = (savedAutoRotate ~= false)
        end
        camera.CameraType = previousCameraType or Enum.CameraType.Custom
        camera.CFrame = goalCam

        -- Force Roblox CameraModule into First-Person (0.5 zoom distance)
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = 0.5

        if not freezeCharacter and root then
            root.Anchored = false
        end
        isWardrobeMode = false
        isWardrobeAnimating = false
        if updateCamlockFovVisual then updateCamlockFovVisual() end

        -- Re-summon main UI if it was visible before wardrobe
        if wasMainUIVisibleBeforeWardrobe then
            wasMainUIVisibleBeforeWardrobe = false
            summonUIWithAnimation()
        else
            task.defer(function()
                if not isUIVisible then
                    player.CameraMaxZoomDistance = 128
                end
            end)
        end
    end
end

wardrobeCloseBtn.Activated:Connect(function()
    hideWardrobeWithAnimation()
end)

-- ====================================================================
-- ScreenGui Trigger Controls (Roblox Logo Triple-Tap + Hotkeys)
-- ====================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpatialUI_SecretOpener"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = targetGuiParent

-- 1. Screen Trigger Configuration
updateToggleBtnState = function(open)
    -- Floating pill button removed per user request
end

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
local espRefreshTimer = 0
local loopConnection = RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    -- Periodic ESP refresh for newly spawned characters/NPCs
    if espEnabled then
        espRefreshTimer = espRefreshTimer + dt
        if espRefreshTimer >= 0.35 then
            espRefreshTimer = 0
            updateESP()
        end
    end

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
-- 2. Post-Camera Camlock Execution (Precise camera aim tracking)
-- ====================================================================
local CAMLOCK_BIND_NAME = "SpatialUI_CamlockPostRender"
RunService:BindToRenderStep(CAMLOCK_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
    if isWardrobeMode or isWardrobeVisible then return end
    if camlockEnabled and isTargetLocked and lockedTargetPart then
        local targetChar = lockedTargetPart.Parent
        local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
        local myRoot = getRootPart()

        local targetValid = false
        if lockedTargetPart and myRoot then
            local targetChar = lockedTargetPart.Parent
            if isCharacterAliveAndValid and isCharacterAliveAndValid(targetChar, lockedTargetPart) then
                local dist = (lockedTargetPart.Position - myRoot.Position).Magnitude
                if dist <= (CAMLOCK_MAX_DIST * 1.25) then
                    local withinFov = true
                    if camlockUseFovLimit then
                        local viewport = camera.ViewportSize
                        local screenCenter = (viewport.X > 0 and viewport.Y > 0) and (viewport / 2) or Vector2.new(960, 540)
                        local screenPos, onScreen = camera:WorldToViewportPoint(lockedTargetPart.Position)
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if not onScreen or screenDist > (camlockFovRadius * 1.5) then
                            withinFov = false
                        end
                    end
                    if withinFov then
                        targetValid = true
                        local currentCamPos = camera.CFrame.Position
                        local targetPos = lockedTargetPart.Position
                        
                        -- Target aim direction toward locked part
                        local targetLookCFrame = CFrame.lookAt(currentCamPos, targetPos)
                        
                        -- Smoothly lerp camera rotation after CameraModule finishes
                        camera.CFrame = camera.CFrame:Lerp(targetLookCFrame, CAMLOCK_SMOOTHNESS)
                    end
                end
            end
        end

        if not targetValid then
            -- Auto-switch to next best target if current target died or went out of range
            local nextTarget = getNearestTargetToCamera()
            if nextTarget then
                lockedTargetPart = nextTarget
                local targetPlayer = Players:GetPlayerFromCharacter(nextTarget.Parent)
                updateCamlockButtonVisual(true, targetPlayer or nextTarget.Parent.Name)
                
                local currentCamPos = camera.CFrame.Position
                local targetPos = nextTarget.Position
                local targetLookCFrame = CFrame.lookAt(currentCamPos, targetPos)
                camera.CFrame = camera.CFrame:Lerp(targetLookCFrame, CAMLOCK_SMOOTHNESS)
            else
                isTargetLocked = false
                lockedTargetPart = nil
                updateCamlockButtonVisual(false)
            end
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
