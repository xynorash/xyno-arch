# xyno-arch

My Arch Linux desktop: Hyprland with a Tokyo Night palette, tuned for gaming on
older NVIDIA hardware.

![wallpaper](wallpapers/starry-night-tokyo.png)

## The setup

| | |
|---|---|
| Compositor | Hyprland (Lua config, dwindle layout) |
| Shell | noctalia — bar, launcher, notifications, lock screen, OSD |
| Terminal | Ghostty |
| File manager | Yazi |
| Login | greetd + tuigreet, matrix background |
| Theme | Tokyo Night, pushed to Hyprland/Ghostty/GTK/Yazi by noctalia's templates |
| Font | JetBrainsMono Nerd Font |
| Boot | systemd-boot with a Unified Kernel Image |
| Filesystem | btrfs with snapper, zram swap |

Built for a Ryzen 7 5800X with a GTX 980 (Maxwell, 4 GB), 1080p @ 60 Hz.

## Install

```sh
git clone https://github.com/xynorash/xyno-arch.git ~/xyno-arch
cd ~/xyno-arch
./install.sh            # symlink the home configs
./install.sh --system   # also the /etc bits (sudo)
```

Existing files are moved to `*.bak-<timestamp>` rather than overwritten.
Package lists live in `packages/` (`pacman.txt`, `aur.txt`).

## Layout

```
home/       dotfiles, symlinked into $HOME
system/     /etc and /boot files, copied by --system
wallpapers/ generated wallpaper (referenced by config.toml)
tools/      wallpaper generator
packages/   explicit pacman and AUR package lists
```

## Keybindings

`Super + Shift + /` prints the full list in a floating terminal — it is parsed
straight out of `hyprland.lua`, so it can't go stale.

| Key | Action |
|---|---|
| `Super + T` | Terminal |
| `Super + E` | File manager (Yazi) |
| `Super + D` | Launcher |
| `Super + Alt + J` | JetBrains Toolbox |
| `Super + Q` | Close window |
| `Super + H/J/K/L` | Move focus |
| `Super + Ctrl + H/J/K/L` | Move window |
| `Super + 1-9` | Workspaces |
| `Super + S` | Flip split direction (dwindle) |
| `Super + V` | Toggle floating |
| `Super + Alt + L` | Lock |
| `Alt + Shift` | Switch keyboard layout (US / French AZERTY) |
| `Print` | Screenshot |

## Gaming

- **GameMode automatically.** A `window.open` hook in `hyprland.lua` matches
  `steam_app_<id>` windows and puts the game's process into GameMode, so the CPU
  governor switches to performance for the game and back afterwards. No
  per-game launch options needed.
- **sched_ext / scx_lavd** as the system scheduler, in gaming mode.
- **NVIDIA power limit** raised from 180 W to the card's 225 W maximum by a
  systemd unit, so it holds boost clocks under load.
- **Direct scanout and tearing** for Steam windows only; the desktop stays
  tear-free.
- **MangoHud** with VRAM on screen (`Right Shift + F12`) — the 4 GB card makes
  VRAM the number worth watching.
- **NTSYNC** module loaded for Wine builds that can use it.

## Notes

- `hyprland.lua` uses the Lua config format. hyprlang (`hyprland.conf`) is
  deprecated as of Hyprland 0.55.
- noctalia writes `noctalia.lua`, `settings.toml` and the Yazi theme itself;
  those are gitignored so generated files don't fight the repo. Everything that
  defines the look — palette, bar geometry, wallpaper, lock screen, widgets —
  lives in the tracked `config.toml`, which overrides nothing and is overridden
  by the state file only if you change the same setting through the GUI. What
  stays untracked is per-monitor widget placement.
- `system/etc/mkinitcpio.conf`, `system/etc/kernel/cmdline` and
  `system/boot/loader/loader.conf` are **not** installed automatically. They
  replace files tied to the boot setup — diff them first, then run
  `sudo mkinitcpio -P`.
- Paths inside `hyprland.lua` and `noctalia/config.toml` are absolute
  (`/home/xynorash/...`). Adjust them for another username.
