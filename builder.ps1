$ErrorActionPreference = "Stop"

$src = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$text = Get-Content $src -Raw

# Normalize line endings to `\n` first
$text = $text -replace "\r\n", "`n"

function Assert-Replace($pattern, $replacement, [ref]$targetText, $desc) {
    if (-not ($targetText.Value -match $pattern)) {
        Write-Error "Failed to match: $desc"
    }
    $targetText.Value = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline).Replace($targetText.Value, $replacement, 1)
    Write-Host "[OK] Matched and replaced: $desc"
}

# 1. Forward Declarations
$forwardHeader = @"
-- ====================================================================
-- Universal Forward Declarations (Shared UI Handles & Cross-Module Functions)
-- Solves Luau's 200 local registers per chunk limit
-- ====================================================================
local screenHudGui, hudContainer, hudStroke, speedNumLabel, unitLabel, gaugeFill
local autoJumpBtn, autoJumpStroke, btnStatusText
local camlockBtn, camlockStroke, camlockStatusText
local setCamlockButtonVisible, updateCamlockButtonVisual
local setBhopScreenWidgets

local uiPart, surfaceGui, backSurfaceGui, container, sidebar, mainFrame
local tabIndicator, titleLabel, closeBtn, minBtn, trackViewport, pagesTrack, grabBarContainer
local currentPartWidth, currentPartHeight = 4.8, 3.8
local currentTabIndex = 1
local typewriteTitle

local playerPage, visualsPage, settingsPage
local createToggleRow, createSliderRow, createActionButton

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
-- ScreenGui สำหรับ HUD ต่างๆ บนหน้าจอ
-- ====================================================================
do
    screenHudGui = Instance.new("ScreenGui")
"@

Assert-Replace '-- ====================================================================\n-- ScreenGui สำหรับ HUD ต่างๆ บนหน้าจอ\n-- ====================================================================\nlocal screenHudGui = Instance.new\("ScreenGui"\)' $forwardHeader ([ref]$text) "HUD Start"

# Replace local declarations in HUD
$text = $text -replace 'local hudContainer = Instance\.new\(', 'hudContainer = Instance.new('
$text = $text -replace 'local hudStroke = Instance\.new\(', 'hudStroke = Instance.new('
$text = $text -replace 'local speedNumLabel = Instance\.new\(', 'speedNumLabel = Instance.new('
$text = $text -replace 'local unitLabel = Instance\.new\(', 'unitLabel = Instance.new('
$text = $text -replace 'local gaugeFill = Instance\.new\(', 'gaugeFill = Instance.new('
$text = $text -replace 'local autoJumpBtn = Instance\.new\(', 'autoJumpBtn = Instance.new('
$text = $text -replace 'local autoJumpStroke = Instance\.new\(', 'autoJumpStroke = Instance.new('
$text = $text -replace 'local btnStatusText = Instance\.new\(', 'btnStatusText = Instance.new('
$text = $text -replace 'local camlockBtn = Instance\.new\(', 'camlockBtn = Instance.new('
$text = $text -replace 'local camlockStroke = Instance\.new\(', 'camlockStroke = Instance.new('
$text = $text -replace 'local camlockStatusText = Instance\.new\(', 'camlockStatusText = Instance.new('
$text = $text -replace 'local function setCamlockButtonVisible\(visible\)', 'setCamlockButtonVisible = function(visible)'
$text = $text -replace 'local function updateCamlockButtonVisual\(isLocked, targetPlayer\)', 'updateCamlockButtonVisual = function(isLocked, targetPlayer)'
$text = $text -replace 'local function setBhopScreenWidgets\(visible\)', 'setBhopScreenWidgets = function(visible)'

# Close HUD block, Open 3D Part block
$partHeader = @"
end -- [End HUD Block]

-- ====================================================================
-- 3D Part & SurfaceGui Setup
-- ====================================================================
do
    uiPart = Instance.new("Part")
"@
Assert-Replace '-- ====================================================================\n-- 3D Part & SurfaceGui Setup\n-- ====================================================================\nlocal currentPartWidth = 4\.8\nlocal currentPartHeight = 3\.8\n\nlocal uiPart = Instance\.new\("Part"\)' $partHeader ([ref]$text) "3D Part Start"

$text = $text -replace 'local surfaceGui = Instance\.new\(', 'surfaceGui = Instance.new('
$text = $text -replace 'local backSurfaceGui = Instance\.new\(', 'backSurfaceGui = Instance.new('
$text = $text -replace 'local container = Instance\.new\(', 'container = Instance.new('
$text = $text -replace 'local sidebar = Instance\.new\(', 'sidebar = Instance.new('
$text = $text -replace 'local tabIndicator = Instance\.new\(', 'tabIndicator = Instance.new('
$text = $text -replace 'local mainFrame = Instance\.new\(', 'mainFrame = Instance.new('
$text = $text -replace 'local titleLabel = Instance\.new\(', 'titleLabel = Instance.new('
$text = $text -replace 'local closeBtn = Instance\.new\(', 'closeBtn = Instance.new('
$text = $text -replace 'local minBtn = Instance\.new\(', 'minBtn = Instance.new('
$text = $text -replace 'local trackViewport = Instance\.new\(', 'trackViewport = Instance.new('
$text = $text -replace 'local pagesTrack = Instance\.new\(', 'pagesTrack = Instance.new('
$text = $text -replace 'local grabBarContainer = Instance\.new\(', 'grabBarContainer = Instance.new('
$text = $text -replace 'local currentTabIndex = 1\n', ''
$text = $text -replace 'local function typewriteTitle\(targetText\)', 'typewriteTitle = function(targetText)'

$text = $text -replace 'local playerPage = createPageColumn\(1\)', 'playerPage = createPageColumn(1)'
$text = $text -replace 'local visualsPage = createPageColumn\(2\)', 'visualsPage = createPageColumn(2)'
$text = $text -replace 'local settingsPage = createPageColumn\(3\)', 'settingsPage = createPageColumn(3)'
$text = $text -replace 'local function createToggleRow\(', 'createToggleRow = function('
$text = $text -replace 'local function createSliderRow\(', 'createSliderRow = function('
$text = $text -replace 'local function createActionButton\(', 'createActionButton = function('

# Close 3D Part block, Open Mobile Controls block
$mobileHeader = @"
end -- [End 3D UI Block]

-- ====================================================================
-- ScreenGui สำหรับปุ่มควบคุมบินบนมือถือ
-- ====================================================================
do
    mobileGui = Instance.new("ScreenGui")
"@
Assert-Replace '-- ====================================================================\n-- ScreenGui สำหรับปุ่มควบคุมบินบนมือถือ\n-- ====================================================================\nlocal mobileGui = Instance\.new\("ScreenGui"\)' $mobileHeader ([ref]$text) "Mobile Controls Start"

$text = $text -replace 'local mobileFlyFrame = Instance\.new\(', 'mobileFlyFrame = Instance.new('

# Close Mobile Controls block, Open Universal Features block
$featuresHeader = @"
end -- [End Mobile Controls Block]

-- ====================================================================
-- Universal Features Logic
-- ====================================================================
do
    startFly = function()
"@
Assert-Replace '-- ====================================================================\n-- Universal Features Logic\n-- ====================================================================\nlocal flyAttachment, flyVelocity, flyAlign\nlocal function startFly\(\)' $featuresHeader ([ref]$text) "Universal Features Start"

$text = $text -replace 'local function stopFly\(\)', 'stopFly = function()'
$text = $text -replace 'local function updateESP\(\)', 'updateESP = function()'
$text = $text -replace 'local function applyFullbright\(enable\)', 'applyFullbright = function(enable)'

# Close Universal Features block, Open Wardrobe & Drag Handlers Block
$wardrobeHeader = @"
end -- [End Universal Features Block]

-- ====================================================================
-- Wardrobe & Character Look 3D UI Setup & Drag Handlers
-- ====================================================================
do
    wardrobePart = Instance.new("Part")
"@
Assert-Replace '-- ====================================================================\n-- Wardrobe & Character Look 3D UI Setup\n-- ====================================================================\nlocal isWardrobeVisible = false\nlocal isWardrobeAnimating = false\nlocal summonWardrobeWithAnimation, hideWardrobeWithAnimation\n\nlocal wardrobePart = Instance\.new\("Part"\)' $wardrobeHeader ([ref]$text) "Wardrobe Start"

$text = $text -replace 'local wardrobeSurfaceGui = Instance\.new\(', 'wardrobeSurfaceGui = Instance.new('
$text = $text -replace 'local wardrobeBackSurfaceGui = Instance\.new\(', 'wardrobeBackSurfaceGui = Instance.new('
$text = $text -replace 'local wardrobeContainer = Instance\.new\(', 'wardrobeContainer = Instance.new('
$text = $text -replace 'local wardrobeMainWindow = Instance\.new\(', 'wardrobeMainWindow = Instance.new('
$text = $text -replace 'local wardrobeCloseBtn = Instance\.new\(', 'wardrobeCloseBtn = Instance.new('
$text = $text -replace 'local wardrobeGrabBarContainer = Instance\.new\(', 'wardrobeGrabBarContainer = Instance.new('
$text = $text -replace 'local wardrobeVisualBar = Instance\.new\(', 'wardrobeVisualBar = Instance.new('
$text = $text -replace 'local profileBtn = Instance\.new\(', 'profileBtn = Instance.new('
$text = $text -replace 'local profileStroke = Instance\.new\(', 'profileStroke = Instance.new('
$text = $text -replace 'local resizeHandle = Instance\.new\(', 'resizeHandle = Instance.new('
$text = $text -replace 'local visualBar = Instance\.new\(', 'visualBar = Instance.new('
$text = $text -replace 'local line1 = Instance\.new\(', 'line1 = Instance.new('
$text = $text -replace 'local line2 = Instance\.new\(', 'line2 = Instance.new('
$text = $text -replace 'local function restoreCharacterAppearance\(\)', 'restoreCharacterAppearance = function()'

# Close Wardrobe & Drag Handlers block, Open Camera Alignment Zoom
$zoomHeader = @"
UserInputService.InputEnded:Connect(endDragOrResize)
end -- [End Wardrobe & Drag Handlers Block]

-- ====================================================================
-- Camera Alignment Zoom
-- ====================================================================
do
    performZoomInAndAlign = function()
"@
Assert-Replace 'UserInputService\.InputEnded:Connect\(endDragOrResize\)\n\n-- ====================================================================\n-- Camera Alignment Zoom\n-- ====================================================================\nlocal function performZoomInAndAlign\(\)' $zoomHeader ([ref]$text) "Camera Alignment Zoom Start"

$text = $text -replace 'local function performZoomOut\(\)', 'performZoomOut = function()'

# Close Camera Alignment Zoom, Open Hide & Summon Animations
$animHeader = @"
    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 128
end
end -- [End Camera Alignment Zoom Block]

-- ====================================================================
-- Hide & Summon Animations
-- ====================================================================
hideUIWithAnimation = function()
"@
Assert-Replace '    player\.CameraMinZoomDistance = 0\.5\n    player\.CameraMaxZoomDistance = 128\nend\n\n-- ====================================================================\n-- Hide & Summon Animations\n-- ====================================================================\nlocal function hideUIWithAnimation\(\)' $animHeader ([ref]$text) "Animations Start"

$text = $text -replace 'local function summonUIWithAnimation\(\)', 'summonUIWithAnimation = function()'

# Clean up redundant declarations
$text = $text -replace 'local updateToggleBtnState = function\(open\) end\n', ''
$text = $text -replace 'local isWardrobeMode = false\n', ''
$text = $text -replace 'local orbitConn = nil\n', ''
$text = $text -replace 'local orbitInputBeganConn = nil\n', ''
$text = $text -replace 'local orbitInputEndedConn = nil\n', ''
$text = $text -replace 'local orbitInputChangedConn = nil\n', ''
$text = $text -replace 'local function cleanupOrbitController\(\)', 'cleanupOrbitController = function()'
$text = $text -replace 'local function setupOrbitController\(', 'setupOrbitController = function('

# Convert back to CRLF for Windows
$text = $text -replace "`n", "`r`n"

$destFiles = @(
    "C:\Users\ASUS\Downloads\3d ui beta.lua",
    "C:\Users\ASUS\Downloads\main.lua",
    "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta\3d ui beta.lua",
    "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta\main.lua"
)

foreach ($dest in $destFiles) {
    [System.IO.File]::WriteAllText($dest, $text, [System.Text.Encoding]::UTF8)
    Write-Host "Updated -> $dest"
}

Write-Host "[SUCCESS] All replacements validated and written successfully!" -ForegroundColor Green
