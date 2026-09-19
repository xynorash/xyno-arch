#!/usr/bin/env bash
# Pretty-print the keybinds declared in hyprland.lua.
# Bound to SUPER+? — see the "Help" section of hyprland.lua.
#
# Pages itself: the caller just runs this script, no `| less` needed.
# Falls back through less -> more -> hold-open, so a missing pager cannot
# make the cheatsheet flash up and vanish.

set -euo pipefail

if [ -t 1 ] && [ "${KEYBINDS_PAGED:-}" != "1" ]; then
    export KEYBINDS_PAGED=1
    if command -v less >/dev/null 2>&1; then
        "$0" | less -R
        exit 0
    elif command -v more >/dev/null 2>&1; then
        "$0" | more
        exit 0
    else
        "$0"
        printf '  Press Enter to close. '
        read -r _
        exit 0
    fi
fi

conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"

awk '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

# local mod = "SUPER"  -> render $mod as SUPER
/^[ \t]*local[ \t]+[A-Za-z_]+[ \t]*=[ \t]*"/ {
    eq = index($0, "=")
    name = trim(substr($0, 1, eq - 1)); sub(/^local[ \t]+/, "", name)
    val  = trim(substr($0, eq + 1))
    sub(/^"/, "", val); sub(/"[ \t]*$/, "", val)
    vars[name] = val
    next
}

# A short -- comment above a bind becomes its section heading.
/^[ \t]*--/ {
    c = trim($0); sub(/^--+[ \t]*/, "", c)
    gsub(/^[─ ]+|[─ ]+$/, "", c)
    sub(/ *—.*$/, "", c)
    if (c ~ /^[A-Za-z]/ && length(c) < 40) pending = c
    next
}

/hl\.bind\(/ {
    line = $0

    # Split key expression from dispatcher at the comma before hl.dsp.
    # Must tolerate column alignment, i.e. several spaces.
    if (!match(line, /,[ \t]*hl\.dsp/)) next
    keyexpr = substr(line, 1, RSTART - 1)
    action  = substr(line, RSTART + 1)
    sub(/^[ \t]*/, "", action)

    sub(/^[ \t]*hl\.bind\([ \t]*/, "", keyexpr)

    # Loop-generated workspace binds: mod .. " + " .. i
    looped = (keyexpr ~ /\.\.[ \t]*i[ \t]*$/)

    gsub(/"/, "", keyexpr)
    gsub(/\.\./, " ", keyexpr)
    for (v in vars) gsub("\\<" v "\\>", vars[v], keyexpr)
    if (looped) sub(/[ \t]+i[ \t]*$/, " 1..9", keyexpr)
    gsub(/[ \t]+/, " ", keyexpr)
    combo = trim(keyexpr)
    gsub(/ \+ +/, " + ", combo)

    # Dispatcher -> readable action
    sub(/\)[ \t]*$/, "", action)
    sub(/,[ \t]*\{[^}]*\}[ \t]*$/, "", action)   # drop the opts table
    a = action

    if (a ~ /exec_cmd\(/) {
        sub(/^.*exec_cmd\([ \t]*/, "", a); sub(/\)[ \t]*$/, "", a)
        if (a ~ /^"/) { sub(/^"/, "", a); sub(/"[ \t]*$/, "", a) }
        else if (a in vars) a = vars[a]
        if (a ~ /keybinds\.sh/) a = "Show this list"
    }
    else if (a ~ /window\.close/)        a = "close window"
    else if (a ~ /window\.float/)        a = "toggle floating"
    else if (a ~ /window\.pseudo/)       a = "toggle pseudotile"
    else if (a ~ /window\.drag/)         a = "drag window"
    else if (a ~ /window\.resize/)       a = "resize window"
    else if (a ~ /window\.move\(\{ *workspace/) a = "move window to workspace"
    else if (a ~ /window\.move/)      { dir = a; sub(/^.*direction *= *"/, "", dir); sub(/".*$/, "", dir); a = "move window " dir }
    else if (a ~ /focus\(\{ *workspace *= *"e\+1/) a = "next workspace"
    else if (a ~ /focus\(\{ *workspace *= *"e-1/)  a = "previous workspace"
    else if (a ~ /focus\(\{ *workspace/) a = "go to workspace"
    else if (a ~ /focus\(/)           { dir = a; sub(/^.*direction *= *"/, "", dir); sub(/".*$/, "", dir); a = "focus " dir }
    else if (a ~ /layout\(/)          { dir = a; sub(/^.*layout\([ \t]*"/, "", dir); sub(/".*$/, "", dir); a = dir }
    else if (a ~ /dsp\.exit/)            a = "exit Hyprland"
    else { sub(/^hl\.dsp\./, "", a); sub(/\(.*$/, "", a) }

    # Prettify keysyms
    gsub(/\<minus\>/,      "-",           combo)
    gsub(/\<equal\>/,      "=",           combo)
    gsub(/\<mouse_down\>/, "Scroll Down", combo)
    gsub(/\<mouse_up\>/,   "Scroll Up",   combo)
    gsub(/mouse:272/,      "Left Drag",   combo)
    gsub(/mouse:273/,      "Right Drag",  combo)
    gsub(/XF86/,           "",            combo)

    if (pending != "" && pending != section) {
        section = pending
        printf "\n  \033[1;35m%s\033[0m\n", section
    }
    pending = ""
    printf "    \033[1;36m%-30s\033[0m %s\n", combo, a
}

/[^ \t]/ { if ($0 !~ /^[ \t]*--/) pending = pending }

BEGIN { printf "\n  \033[1mHyprland keybinds\033[0m\n" }
END   { printf "\n" }
' "$conf"

printf '  \033[2mPress q to close.\033[0m\n\n'
