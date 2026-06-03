-- ============================================================
--  Atlanta UI Library — Full Mobile Support Patch
--  Drop this BELOW the library load line but BEFORE any UI
--  setup in your script.
--
--  Usage (in atlanta_example.lua):
--
--    local library, themes = loadstring(game:HttpGet(...))()
--    loadstring(game:HttpGet("YOUR_RAW_PATCH_URL"))()   -- ← add this
--    ... rest of your script ...
--
--  Or just paste this whole block directly after the first
--  loadstring line.
-- ============================================================

local uis         = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local players     = cloneref and cloneref(game:GetService("Players"))          or game:GetService("Players")
local ws          = cloneref and cloneref(game:GetService("Workspace"))        or game:GetService("Workspace")
local tween_svc   = cloneref and cloneref(game:GetService("TweenService"))     or game:GetService("TweenService")
local run         = cloneref and cloneref(game:GetService("RunService"))       or game:GetService("RunService")

local camera  = ws.CurrentCamera
local lp      = players.LocalPlayer
local dim2    = UDim2.new
local dim     = UDim.new
local vec2    = Vector2.new
local rgb     = Color3.fromRGB
local hex     = Color3.fromHex
local clamp   = math.clamp
local floor   = math.floor

-- ─── helpers ────────────────────────────────────────────────
local function isMobile()
    return uis.TouchEnabled and not uis.KeyboardEnabled
end

local function tween(obj, props, t)
    t = t or 0.18
    local ok, tw = pcall(function()
        return tween_svc:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and tw then tw:Play() end
end

-- ─── 1. REPLACE draggify WITH TOUCH-AWARE VERSION ───────────
--  Patches library.draggify so all existing and future panels
--  respond to both mouse and touch input.
-- ────────────────────────────────────────────────────────────
local _old_draggify = library.draggify
function library:draggify(frame)
    local dragging  = false
    local startPos  = frame.Position
    local startInput

    local function onBegan(input)
        local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        if not (isMouse or isTouch) then return end

        dragging   = true
        startInput = input.Position
        startPos   = frame.Position

        if library.current_element_open then
            library.current_element_open.set_visible(false)
            library.current_element_open.open = false
            library.current_element_open = nil
        end

        if frame.Parent and frame.Parent:IsA("ScreenGui") and frame.Parent.DisplayOrder ~= 999999 then
            library.display_orders = (library.display_orders or 0) + 1
            frame.Parent.DisplayOrder = library.display_orders
        end
    end

    local function onEnded(input)
        local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        if isMouse or isTouch then
            dragging = false
        end
    end

    local function onChanged(input)
        local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        if dragging and (isMouse or isTouch) then
            local vx = camera.ViewportSize.X
            local vy = camera.ViewportSize.Y
            local newPos = dim2(
                0,
                clamp(startPos.X.Offset + (input.Position.X - startInput.X), 0, vx - frame.AbsoluteSize.X),
                0,
                clamp(startPos.Y.Offset + (input.Position.Y - startInput.Y), 0, vy - frame.AbsoluteSize.Y)
            )
            frame.Position = newPos
        end
    end

    frame.InputBegan:Connect(onBegan)
    frame.InputEnded:Connect(onEnded)
    uis.InputChanged:Connect(onChanged)
end

-- ─── 2. TOUCH-AWARE SLIDER ──────────────────────────────────
--  Wraps library.slider so the fill-bar responds to touch
--  drag in addition to mouse drag.
-- ────────────────────────────────────────────────────────────
local _old_slider = library.slider
function library:slider(options)
    local result = _old_slider(self, options)

    -- Find the slider bar (the inner fill frame) by walking the
    -- holder's children after creation.
    task.defer(function()
        -- The slider attaches its InputBegan to the bar frame.
        -- We need to find that frame and add Touch support.
        local holder = self and self.holder
        if not holder then return end

        -- Walk recent children to find slider track
        for _, child in holder:GetChildren() do
            if child:IsA("Frame") and child.Size.Y.Scale == 0 and child.Size.Y.Offset > 6 then
                -- Likely the slider outline wrapper
                local function addTouchToBar(bar)
                    local dragging  = false
                    local startX    = 0
                    local startVal  = 0

                    bar.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            startX   = inp.Position.X
                        end
                    end)

                    bar.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                        end
                    end)

                    uis.InputChanged:Connect(function(inp)
                        if dragging and inp.UserInputType == Enum.UserInputType.Touch then
                            local rel  = clamp((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                            local min_ = options.min  or 0
                            local max_ = options.max  or 100
                            local iv   = options.interval or 1
                            local raw  = min_ + rel * (max_ - min_)
                            local snapped = floor(raw / iv + 0.5) * iv
                            snapped = clamp(snapped, min_, max_)

                            if result and result.set then
                                pcall(result.set, snapped)
                            end
                        end
                    end)
                end

                for _, inner in child:GetDescendants() do
                    if inner:IsA("Frame") and inner.Name == "" then
                        addTouchToBar(inner)
                    end
                end
            end
        end
    end)

    return result
end

-- ─── 3. MOBILE TOGGLE BUTTON ────────────────────────────────
--  Creates a persistent floating button in the top-right
--  corner (or wherever you drag it) that shows/hides the
--  entire Atlanta menu.  Only rendered when touch is enabled.
-- ────────────────────────────────────────────────────────────
local function create_mobile_toggle(window)
    -- window must be the object returned by library:window()
    -- We call it in atlanta_example.lua AFTER library:window()

    local sgui_mobile = Instance.new("ScreenGui")
    sgui_mobile.Name             = "AtlantaMobileToggle"
    sgui_mobile.ResetOnSpawn     = false
    sgui_mobile.IgnoreGuiInset   = true
    sgui_mobile.DisplayOrder     = 1000000
    sgui_mobile.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    pcall(function() sgui_mobile.Parent = gethui() end)
    if not sgui_mobile.Parent then
        sgui_mobile.Parent = lp:WaitForChild("PlayerGui")
    end

    -- Outer shell (outline border)
    local outline = Instance.new("Frame")
    outline.Name             = "Outline"
    outline.Size             = dim2(0, 44, 0, 44)
    outline.Position         = dim2(1, -58, 0, 12)   -- top-right
    outline.BackgroundColor3 = hex("#0A0A0A")
    outline.BorderSizePixel  = 0
    outline.Active           = true
    outline.Parent           = sgui_mobile

    local accent = Instance.new("Frame")
    accent.Name             = "Accent"
    accent.Size             = dim2(1, -2, 1, -2)
    accent.Position         = dim2(0, 1, 0, 1)
    accent.BackgroundColor3 = hex("#b4b4ff")
    accent.BorderSizePixel  = 0
    accent.Parent           = outline

    local inner = Instance.new("Frame")
    inner.Name             = "Inner"
    inner.Size             = dim2(1, -2, 1, -2)
    inner.Position         = dim2(0, 1, 0, 1)
    inner.BackgroundColor3 = hex("#1E1E1E")
    inner.BorderSizePixel  = 0
    inner.Parent           = accent

    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color    = ColorSequence.new{
        ColorSequenceKeypoint.new(0, rgb(35, 35, 47)),
        ColorSequenceKeypoint.new(1, rgb(41, 41, 55)),
    }
    grad.Parent = inner

    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = outline
    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 5)
    corner2.Parent = accent
    local corner3 = Instance.new("UICorner")
    corner3.CornerRadius = UDim.new(0, 4)
    corner3.Parent = inner

    -- Hamburger / X icon label
    local icon = Instance.new("TextLabel")
    icon.Name                = "Icon"
    icon.Text                = "☰"
    icon.TextColor3          = hex("#b4b4ff")
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel     = 0
    icon.Size                = dim2(1, 0, 1, 0)
    icon.TextSize            = 20
    icon.Font                = Enum.Font.GothamBold
    icon.ZIndex              = 10
    icon.Parent              = inner

    -- Hit button (transparent, on top)
    local btn = Instance.new("TextButton")
    btn.Name                = "HitArea"
    btn.Text                = ""
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel     = 0
    btn.Size                = dim2(1, 0, 1, 0)
    btn.ZIndex              = 20
    btn.Parent              = outline

    -- Drag support for the toggle button itself
    do
        local dragging  = false
        local startPos
        local startInput

        outline.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                dragging   = true
                startPos   = outline.Position
                startInput = inp.Position
            end
        end)

        outline.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        uis.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.Touch then
                local vx = camera.ViewportSize.X
                local vy = camera.ViewportSize.Y
                outline.Position = dim2(
                    0, clamp(startPos.X.Offset + inp.Position.X - startInput.X, 0, vx - 44),
                    0, clamp(startPos.Y.Offset + inp.Position.Y - startInput.Y, 0, vy - 44)
                )
            end
        end)
    end

    -- Toggle click
    local menuVisible = true
    btn.MouseButton1Click:Connect(function()
        menuVisible = not menuVisible
        icon.Text = menuVisible and "☰" or "✕"
        tween(icon, {TextColor3 = menuVisible and hex("#b4b4ff") or hex("#ff6b6b")})
        if window and window.set_menu_visibility then
            window.set_menu_visibility(menuVisible)
        end
    end)

    -- Hide on desktop (only show when touch is available)
    sgui_mobile.Enabled = uis.TouchEnabled

    return {
        gui    = sgui_mobile,
        button = btn,
        set_visible = function(bool)
            sgui_mobile.Enabled = bool
        end
    }
end

-- ─── 4. TOUCH-FRIENDLY SCROLLING ────────────────────────────
--  Makes every ScrollingFrame in the UI respond to touch
--  swipe gestures (runs once after UI is built).
-- ────────────────────────────────────────────────────────────
local function patch_scrolling_frames(root)
    for _, sf in root:GetDescendants() do
        if sf:IsA("ScrollingFrame") then
            local startY = nil
            local startScroll = nil

            sf.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.Touch then
                    startY      = inp.Position.Y
                    startScroll = sf.CanvasPosition.Y
                end
            end)

            sf.InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.Touch and startY then
                    local delta = startY - inp.Position.Y
                    sf.CanvasPosition = Vector2.new(sf.CanvasPosition.X, clamp(startScroll + delta, 0, sf.AbsoluteCanvasSize.Y - sf.AbsoluteSize.Y))
                end
            end)

            sf.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.Touch then
                    startY = nil
                end
            end)
        end
    end
end

-- ─── 5. RESIZE WINDOW FOR SMALL SCREENS ─────────────────────
--  If the viewport is narrower than the default window width,
--  scale down so nothing gets clipped off-screen.
-- ────────────────────────────────────────────────────────────
local function fit_window_to_screen(main_holder)
    if not main_holder then return end

    local vx = camera.ViewportSize.X
    local vy = camera.ViewportSize.Y

    local w = main_holder.AbsoluteSize.X
    local h = main_holder.AbsoluteSize.Y

    -- Clamp to viewport with a small margin
    local margin = 8
    local newW = math.min(w, vx - margin * 2)
    local newH = math.min(h, vy - margin * 2)

    if newW ~= w or newH ~= h then
        main_holder.Size = dim2(0, newW, 0, newH)
    end

    -- Re-centre
    main_holder.Position = dim2(
        0, clamp(main_holder.Position.X.Offset, margin, vx - newW - margin),
        0, clamp(main_holder.Position.Y.Offset, margin, vy - newH - margin)
    )
end

-- ─── 6. PUBLIC API ───────────────────────────────────────────
--  Call  library.init_mobile(window)  AFTER library:window()
--  in your script.  That's the only line you need to add.
-- ────────────────────────────────────────────────────────────
function library.init_mobile(window)
    -- Small screens: fit the main panel
    task.defer(function()
        -- Give the UI a frame to fully lay out
        run.RenderStepped:Wait()

        -- Find the main_holder across all library guis
        for _, gui in library.guis do
            for _, child in gui:GetChildren() do
                if child:IsA("Frame") and child.Active then
                    fit_window_to_screen(child)
                end
            end
        end

        -- Patch scrolling frames
        for _, gui in library.guis do
            patch_scrolling_frames(gui)
        end
    end)

    -- Create the floating toggle button
    local toggle = create_mobile_toggle(window)
    return toggle
end

-- ─── USAGE REMINDER (printed to output) ─────────────────────
if isMobile() then
    print("[Atlanta Mobile Patch] Touch device detected — mobile support active.")
    print("[Atlanta Mobile Patch] Call   library.init_mobile(window)   after library:window() to enable the toggle button.")
else
    print("[Atlanta Mobile Patch] Loaded (desktop mode — mobile toggle hidden).")
end
