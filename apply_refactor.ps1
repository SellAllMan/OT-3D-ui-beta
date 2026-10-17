$sourcePath = "C:\Users\ASUS\Downloads\3d_ui_backups\3d_ui_backup_20261017_123822.lua"
$text = Get-Content $sourcePath -Raw

# 1. Forward declarations before HUD
$hudHeader = @"
-- ====================================================================
-- Forward Declarations for Shared UI Components (Prevent Luau 200 register overflow)
-- ====================================================================
local screenHudGui, hudContainer, hudStroke, speedNumLabel, unitLabel, gaugeFill
local autoJumpBtn, autoJumpStroke, btnStatusText
local camlockBtn, camlockStroke, camlockStatusText
local setCamlockButtonVisible, updateCamlockButtonVisual

local uiPart, surfaceGui, backSurfaceGui, container, sidebar, mainFrame
local tabIndicator, titleLabel, closeBtn, minBtn, trackViewport, pagesTrack, grabBarContainer
local currentPartWidth, currentPartHeight = 4.8, 3.8
local currentTabIndex = 1
local typewriteTitle

local mobileGui, mobileFlyFrame

local wardrobePart, wardrobeSurfaceGui, wardrobeBackSurfaceGui, wardrobeContainer, wardrobeMainWindow, wardrobeGrabBarContainer, wardrobeCloseBtn
local wardrobeVisualBar, visualBar, resizeHandle, line1, line2
local profileBtn, profileStroke

-- ====================================================================
-- ScreenGui สำหรับ HUD ต่างๆ บนหน้าจอ
-- ====================================================================
do
    screenHudGui = Instance.new("ScreenGui")
"@

$text = $text.Replace(@"
-- ====================================================================
-- ScreenGui สำหรับ HUD ต่างๆ บนหน้าจอ
-- ====================================================================
local screenHudGui = Instance.new("ScreenGui")
"@, $hudHeader)

# Replace local with assignment in HUD
$text = $text.Replace("local hudContainer = Instance.new(", "hudContainer = Instance.new(")
$text = $text.Replace("local hudStroke = Instance.new(", "hudStroke = Instance.new(")
$text = $text.Replace("local speedNumLabel = Instance.new(", "speedNumLabel = Instance.new(")
$text = $text.Replace("local unitLabel = Instance.new(", "unitLabel = Instance.new(")
$text = $text.Replace("local gaugeFill = Instance.new(", "gaugeFill = Instance.new(")
$text = $text.Replace("local autoJumpBtn = Instance.new(", "autoJumpBtn = Instance.new(")
$text = $text.Replace("local autoJumpStroke = Instance.new(", "autoJumpStroke = Instance.new(")
$text = $text.Replace("local btnStatusText = Instance.new(", "btnStatusText = Instance.new(")
$text = $text.Replace("local camlockBtn = Instance.new(", "camlockBtn = Instance.new(")
$text = $text.Replace("local camlockStroke = Instance.new(", "camlockStroke = Instance.new(")
$text = $text.Replace("local camlockStatusText = Instance.new(", "camlockStatusText = Instance.new(")
$text = $text.Replace("local function setCamlockButtonVisible(visible)", "setCamlockButtonVisible = function(visible)")
$text = $text.Replace("local function updateCamlockButtonVisual(isLocked, targetPlayer)", "updateCamlockButtonVisual = function(isLocked, targetPlayer)")

# Close HUD block before 3D Part setup
$text = $text.Replace(@"
-- ====================================================================
-- 3D Part & SurfaceGui Setup
-- ====================================================================
local currentPartWidth = 4.8
local currentPartHeight = 3.8

local uiPart = Instance.new("Part")
"@, @"
end -- End HUD do-block

-- ====================================================================
-- 3D Part & SurfaceGui Setup
-- ====================================================================
do
    uiPart = Instance.new("Part")
"@)

# Replace local in 3D Part setup
$text = $text.Replace("local surfaceGui = Instance.new(", "surfaceGui = Instance.new(")
$text = $text.Replace("local backSurfaceGui = Instance.new(", "backSurfaceGui = Instance.new(")
$text = $text.Replace("local container = Instance.new(", "container = Instance.new(")
$text = $text.Replace("local sidebar = Instance.new(", "sidebar = Instance.new(")
$text = $text.Replace("local tabIndicator = Instance.new(", "tabIndicator = Instance.new(")
$text = $text.Replace("local mainFrame = Instance.new(", "mainFrame = Instance.new(")
$text = $text.Replace("local titleLabel = Instance.new(", "titleLabel = Instance.new(")
$text = $text.Replace("local closeBtn = Instance.new(", "closeBtn = Instance.new(")
$text = $text.Replace("local minBtn = Instance.new(", "minBtn = Instance.new(")
$text = $text.Replace("local trackViewport = Instance.new(", "trackViewport = Instance.new(")
$text = $text.Replace("local pagesTrack = Instance.new(", "pagesTrack = Instance.new(")
$text = $text.Replace("local grabBarContainer = Instance.new(", "grabBarContainer = Instance.new(")
$text = $text.Replace("local currentTabIndex = 1", "")
$text = $text.Replace("local function typewriteTitle(targetText)", "typewriteTitle = function(targetText)")

# Close 3D Part before Mobile Controls
$text = $text.Replace(@"
-- ====================================================================
-- ScreenGui สำหรับปุ่มควบคุมบินบนมือถือ
-- ====================================================================
local mobileGui = Instance.new("ScreenGui")
"@, @"
end -- End 3D UI do-block

-- ====================================================================
-- ScreenGui สำหรับปุ่มควบคุมบินบนมือถือ
-- ====================================================================
do
    mobileGui = Instance.new("ScreenGui")
"@)

$text = $text.Replace("local mobileFlyFrame = Instance.new(", "mobileFlyFrame = Instance.new(")

# Close Mobile Controls before ESP
$text = $text.Replace(@"
-- ====================================================================
-- Visual Mod Features Logic
-- ====================================================================
"@, @"
end -- End Mobile Controls do-block

-- ====================================================================
-- Visual Mod Features Logic
-- ====================================================================
"@)

# Scope Wardrobe setup
$text = $text.Replace(@"
-- ====================================================================
-- Wardrobe & Character Look 3D UI Setup
-- ====================================================================
local isWardrobeVisible = false
local isWardrobeAnimating = false
local summonWardrobeWithAnimation, hideWardrobeWithAnimation

local wardrobePart = Instance.new("Part")
"@, @"
-- ====================================================================
-- Wardrobe & Character Look 3D UI Setup
-- ====================================================================
local summonWardrobeWithAnimation, hideWardrobeWithAnimation

do
    wardrobePart = Instance.new("Part")
"@)

$text = $text.Replace("local wardrobeSurfaceGui = Instance.new(", "wardrobeSurfaceGui = Instance.new(")
$text = $text.Replace("local wardrobeBackSurfaceGui = Instance.new(", "wardrobeBackSurfaceGui = Instance.new(")
$text = $text.Replace("local wardrobeContainer = Instance.new(", "wardrobeContainer = Instance.new(")
$text = $text.Replace("local wardrobeMainWindow = Instance.new(", "wardrobeMainWindow = Instance.new(")
$text = $text.Replace("local wardrobeCloseBtn = Instance.new(", "wardrobeCloseBtn = Instance.new(")
$text = $text.Replace("local wardrobeGrabBarContainer = Instance.new(", "wardrobeGrabBarContainer = Instance.new(")
$text = $text.Replace("local wardrobeVisualBar = Instance.new(", "wardrobeVisualBar = Instance.new(")
$text = $text.Replace("local profileBtn = Instance.new(", "profileBtn = Instance.new(")
$text = $text.Replace("local profileStroke = Instance.new(", "profileStroke = Instance.new(")
$text = $text.Replace("local resizeHandle = Instance.new(", "resizeHandle = Instance.new(")
$text = $text.Replace("local visualBar = Instance.new(", "visualBar = Instance.new(")
$text = $text.Replace("local line1 = Instance.new(", "line1 = Instance.new(")
$text = $text.Replace("local line2 = Instance.new(", "line2 = Instance.new(")

# Close Wardrobe block before Drag handlers
$text = $text.Replace(@"
-- ====================================================================
-- 3. Drag / Resize Handlers
-- ====================================================================
"@, @"
end -- End Wardrobe do-block

-- ====================================================================
-- 3. Drag / Resize Handlers
-- ====================================================================
do
"@)

$text = $text.Replace(@"
-- ====================================================================
-- Smooth Camera Transition (Zoom In & Zoom Out to Front Facing)
-- ====================================================================
"@, @"
end -- End Drag / Resize Handlers do-block

-- ====================================================================
-- Smooth Camera Transition (Zoom In & Zoom Out to Front Facing)
-- ====================================================================
"@)

$outputPath = "C:\Users\ASUS\.gemini\antigravity\scratch\OT-3D-ui-beta\refactored_test.lua"
Set-Content -Path $outputPath -Value $text -Encoding UTF8
Write-Host "Wrote refactored file. Running register simulation..."
