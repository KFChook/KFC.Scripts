-- Load the library from raw repo
local library = loadstring(game:HttpGet("YOUR_RAW_REPO_URL_HERE"))()

-- Create a window
local Window = library:window({
    name = "My Script",
    suffix = " v1.0",
    game_name = "My Awesome Script for Roblox",
    size = UDim2.new(0, 700, 0, 565)
})

-- Create tabs (returns multiple pages)
local visuals, combat, misc, settings = Window:tab({
    name = "Script",
    tabs = {"Visuals", "Combat", "Misc", "Settings"}
})

-- ============ VISUALS TAB ============
local visualColumn = visuals:column({})
local espSection = visualColumn:section({
    name = "ESP",
    size = 1,
    default = true,
    icon = "rbxassetid://6022668898"
})

-- Toggle
espSection:toggle({
    name = "Enable ESP",
    flag = "esp_enabled",
    default = true,
    callback = function(state)
        print("ESP is now:", state)
    end
})

-- Colorpicker
espSection:colorpicker({
    name = "Box Color",
    flag = "esp_color",
    color = Color3.fromRGB(255, 0, 0),
    alpha = 0.5,
    callback = function(color, alpha)
        print("Color changed to:", color, "Alpha:", alpha)
    end
})

-- Slider
espSection:slider({
    name = "ESP Distance",
    min = 50,
    max = 500,
    default = 250,
    suffix = " studs",
    flag = "esp_distance",
    callback = function(value)
        print("Distance set to:", value)
    end
})

-- Dropdown
espSection:dropdown({
    name = "ESP Type",
    items = {"Box", "Circle", "Glow", "None"},
    default = "Box",
    flag = "esp_type",
    callback = function(value)
        print("ESP type:", value)
    end
})

-- ============ COMBAT TAB ============
local combatColumn = combat:column({})
local aimbotSection = combatColumn:section({
    name = "Aimbot",
    size = 1,
    default = true,
    icon = "rbxassetid://6034767608"
})

aimbotSection:toggle({
    name = "Enable Aimbot",
    flag = "aimbot_enabled",
    default = false,
    callback = function(state)
        print("Aimbot:", state)
    end
})

aimbotSection:slider({
    name = "Aimbot FOV",
    min = 0,
    max = 360,
    default = 120,
    suffix = "°",
    flag = "aimbot_fov",
    callback = function(value)
        print("FOV:", value)
    end
})

aimbotSection:keybind({
    name = "Aimbot Key",
    key = Enum.KeyCode.RightAlt,
    mode = "Hold",
    default = false,
    flag = "aimbot_key",
    callback = function(state)
        print("Keybind state:", state)
    end
})

-- ============ MISC TAB ============
local miscColumn = misc:column({})
local utilitySection = miscColumn:section({
    name = "Utilities",
    size = 1,
    default = true,
    icon = "rbxassetid://139628202576511"
})

-- Textbox
utilitySection:textbox({
    name = "Custom Message",
    placeholder = "Enter message...",
    default = "Hello World!",
    flag = "custom_message",
    callback = function(text)
        print("Message:", text)
    end
})

-- Button
utilitySection:button({
    name = "Print Message",
    callback = function()
        print("Button clicked! Message:", library.flags["custom_message"])
    end
})

-- Label
utilitySection:label({
    name = "Status: Ready",
    info = "Additional info about status"
})

-- Seperator
misc:seperator({name = "Server Options"})

local serverColumn = misc:column({})
local serverSection = serverColumn:section({
    name = "Server",
    size = 1,
    default = true
})

serverSection:button({
    name = "Server Hop",
    callback = function()
        -- Your server hop code here
        print("Server hopping...")
    end
})

serverSection:button({
    name = "Rejoin",
    callback = function()
        -- Your rejoin code here
        print("Rejoining...")
    end
})

-- ============ SETTINGS TAB ============
-- This automatically adds config saving/loading
library:init_config(Window)

-- ============ ACCESS FLAGS ANYTIME ============
-- You can access any flag value from anywhere
task.spawn(function()
    while task.wait(0.1) do
        -- Example: Check if ESP is enabled
        if library.flags["esp_enabled"] then
            -- Render ESP here
            local espColor = library.flags["esp_color"]
            local espDistance = library.flags["esp_distance"]
        end
        
        -- Check aimbot keybind
        if library.flags["aimbot_enabled"] and library.flags["aimbot_key"].active then
            -- Aimbot logic here
        end
    end
end)

-- ============ UNLOAD MENU ============
-- To unload the menu when needed:
-- library:unload_menu()

-- ============ CREATE NOTIFICATION ============
-- Example notification
task.wait(2)
library.notifications:create_notification({
    name = "Script Loaded",
    info = "Successfully loaded all features!",
    lifetime = 5
})
