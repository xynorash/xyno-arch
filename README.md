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
| Command line | bash + oh-my-posh cockpit prompt with transient collapse, ble.sh (history predictions, syntax colours, menu completion with carapace descriptions, fzf history picker), carapace, zoxide, width-responsive fastfetch banner (large/medium logo or compact, rendered in the background) with a chafa-made logo (`home/.config/xynorash/`, `tools/make-logo.sh`); the prompt drops vitals, host and path depth as the terminal narrows |
| File manager | Strata (default for folders; Yazi in the terminal) |
| Login | greetd + tuigreet, matrix background |
| Theme | Tokyo Night, pushed to Hyprland/Ghostty/GTK/Yazi by noctalia's templates |
| Font | JetBrainsMono Nerd Font |
| Boot | systemd-boot with a Unified Kernel Image |
| Filesystem | btrfs with snapper, zram swap |

Built for a Ryzen 7 5800X with a GTX 980 (Maxwell, 4 GB), 1080p @ 60 Hz.

## Install

On a fresh Arch install (UEFI, btrfs, your user created, `base-devel` and `git` present):

```sh
git clone https://github.com/xynorash/xyno-arch.git ~/xyno-arch
cd ~/xyno-arch
./install.sh --packages --system   # packages, home symlinks, /etc files, services, snapper
```

`--packages` needs `yay` first (`git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si`);
without it only the pacman list is installed. The NVIDIA driver is the 580xx branch
for the GTX 980 and builds through DKMS, so `linux-headers` must be installed
(it is in `packages/pacman.txt`).

Existing files are moved to `*.bak-<timestamp>` rather than overwritten.
Paths use `$HOME`; the noctalia config is rewritten for your home if it differs.

### What stays manual (hardware-specific)

- **Disk layout:** btrfs with subvolumes `@` (/), `@home`, `@log`, `@pkg` and a
  `@swap` subvolume holding a 16 GB swapfile
  (`btrfs filesystem mkswapfile --size 16g /swap/swapfile`, priority 10 in fstab; zram is priority 100).
- **Bootloader:** `bootctl install`, then edit `system/etc/kernel/cmdline`
  with your own root `PARTUUID` (`blkid`), and diff/install `mkinitcpio.conf`,
  `mkinitcpio.d/linux.preset` and `boot/loader/loader.conf` before `sudo mkinitcpio -P`.
- **Windows dual boot** is reached through "Reboot Into Firmware Interface".
- **WinApps** (`~/.config/winapps`) is not tracked: it holds a password. Re-run its setup.
- **Keyring:** make the login keyring the default and give it your login password,
  or `gh`/git will find it locked.
- After first boot: `sudo tailscale up`, `gh auth login`.

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
| `Super + E` | File manager (Strata) |
| `Super + Alt + E` | File manager in the terminal (Yazi) |
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
