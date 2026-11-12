-- Laptop-only layer, required at the end of hyprland.lua. install.sh links it only where a battery exists.

-- Touchpad
hl.config({
    input = {
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            clickfinger_behavior = true,
            disable_while_typing = true,
        },
    },
})

-- Brightness keys go through noctalia so its OSD shows
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("noctalia msg brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"), { locked = true, repeating = true })
