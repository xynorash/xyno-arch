-- ─── Hyprland, Omarchy Quattro-style ─────────────────────────────────────
-- Lua config. hyprlang (.conf) is deprecated as of Hyprland 0.55.
-- Colours come from noctalia.lua, regenerated on every theme change.

local mod = "SUPER"

-- ─── Display ─────────────────────────────────────────────────────────────
-- Dell E2314H. Pinned to 1x so the scale can't drift.
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

-- ─── Environment ─────────────────────────────────────────────────────────
-- Wayland-first for every toolkit. DISPLAY is left alone: the Steam client
-- is X11-only and needs XWayland.
hl.env("XDG_CONFIG_HOME", "/home/xynorash/.config")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
-- SDL_VIDEODRIVER deliberately unset — forcing it breaks Steam titles.

-- ─── Autostart ───────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    -- Notification clicks land on the sending app even if it ignores the
    -- activation token.
    hl.exec_cmd("/home/xynorash/.local/bin/notification-focus")
end)

-- ─── Layout & look ───────────────────────────────────────────────────────
hl.config({
    general = {
        layout           = "dwindle",
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 2,
        resize_on_border = true,
        allow_tearing    = false,
    },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
    },

    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        blur = {
            enabled = true,
            size    = 6,
            passes  = 3,
        },

        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
        },
    },

    animations = { enabled = true },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        -- Clicking a notification (toast or Control Center) hands the app an
        -- activation token; honour it so Hyprland jumps to that window.
        focus_on_activate        = true,
    },

    input = {
        -- us + classic AZERTY (plain `fr`, the pre-AFNOR layout).
        -- Both Shift keys + either Alt cycle between them.
        kb_layout          = "us,fr",
        kb_options         = "grp:alt_shift_toggle",
        follow_mouse       = 1,
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
        },
    },
})

-- ─── Animations ──────────────────────────────────────────────────────────
hl.curve("omarchy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("snap",    { type = "bezier", points = { {0.2, 1.0},  {0.2, 1.0}  } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "omarchy" })
hl.animation({ leaf = "border",     enabled = true, speed = 8, bezier = "snap" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "snap" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "omarchy" })

-- ─── Keybinds ────────────────────────────────────────────────────────────
-- Apps
hl.bind(mod .. " + T", hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("ghostty -e yazi"))
hl.bind(mod .. " + ALT + J", hl.dsp.exec_cmd("jetbrains-toolbox"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd("noctalia msg session lock"))
-- Physical power button opens the session menu (same as the bar's power icon)
-- rather than powering off. logind is set to ignore the key so this wins.
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("noctalia msg panel-toggle session"), { locked = true })

-- Help
-- SUPER+? prints this config's binds in a floating terminal.
-- Both keysyms are bound: shift+slash reports as `question` on some layouts.
-- The script pages itself, so no wrapper shell or pager is needed here.
local cheatsheet = "ghostty --class=com.hypr.Keybinds -e /home/xynorash/.config/hypr/keybinds.sh"
hl.bind(mod .. " + SHIFT + slash",    hl.dsp.exec_cmd(cheatsheet))
hl.bind(mod .. " + SHIFT + question", hl.dsp.exec_cmd(cheatsheet))

-- Focus
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))

-- Move windows
hl.bind(mod .. " + CTRL + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + CTRL + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + CTRL + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + CTRL + L", hl.dsp.window.move({ direction = "right" }))

-- Window state
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + S", hl.dsp.layout("togglesplit"))

-- Workspaces
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,          hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + CTRL + " .. i,   hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + U", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + I", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse drag
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots
hl.bind("Print",          hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
hl.bind("SHIFT + Print",  hl.dsp.exec_cmd("noctalia msg screenshot-region"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"))

-- Audio / media — routed through noctalia so the OSD shows
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"),      { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"),    { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("noctalia msg volume-mute"),    { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("noctalia msg mic-mute"),       { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("noctalia msg media toggle"),   { locked = true })
hl.bind("XF86AudioStop",        hl.dsp.exec_cmd("noctalia msg media stop"),     { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("noctalia msg media previous"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("noctalia msg media next"),     { locked = true })

-- For Noctalia Color templates
-- ─── Gaming performance ──────────────────────────────────────────────────
hl.config({
    -- Fullscreen games that ask for it are handed straight to the display,
    -- skipping a composite pass (less GPU work, less latency).
    render  = { direct_scanout = 2, new_render_scheduling = true },
    -- Only permits tearing; the rule below opts Steam games in. Desktop apps
    -- stay tear-free.
    general = { allow_tearing = true },
})
hl.window_rule({
    name      = "steam-games-immediate",
    match     = { class = "^steam_app_" },
    -- Present frames immediately instead of waiting for vblank: lower input
    -- latency, and a GPU below 60 fps never stalls for the next refresh.
    immediate = true,
})

-- ─── GameMode, automatically ─────────────────────────────────────────────
-- Proton names every Steam game window steam_app_<appid>. When one opens,
-- its process joins GameMode (Ryzen -> performance governor, screensaver
-- inhibited). It drops back to powersave ~20 s after the game exits.
-- Steam's own client window is class "steam" and deliberately not matched.
hl.on("window.open", function(w)
    if w and w.initial_class and w.initial_class:match("^steam_app_%d+$") then
        hl.exec_cmd("/home/xynorash/.local/bin/gamemode-attach " .. w.pid)
    end
end)

-- ─── Window rules ────────────────────────────────────────────────────────
hl.window_rule({
    name   = "keybinds-cheatsheet",
    match  = { class = "^(com\\.hypr\\.Keybinds)$" },
    float  = true,
    size   = "900 820",
    center = true,
})

require("noctalia").apply_theme()
