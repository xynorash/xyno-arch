# xyno-arch

My Arch Linux desktop: Hyprland with a Tokyo Night palette on the CachyOS bore kernel,
tuned for gaming on older NVIDIA hardware.

![wallpaper](wallpapers/starry-night-tokyo.png)

## The setup

| | |
|---|---|
| Compositor | Hyprland (Lua config, dwindle layout) |
| Shell | noctalia: bar, launcher, notifications, lock screen, OSD |
| Terminal | Ghostty |
| Command line | bash + oh-my-posh cockpit prompt with transient collapse, ble.sh (history predictions, syntax colours, menu completion with carapace descriptions, fzf history picker), carapace, zoxide, width-responsive fastfetch banner with a chafa-made logo (`home/.config/xynorash/`, `tools/make-logo.sh`); the prompt drops vitals, host and path depth as the terminal narrows |
| File manager | Strata (default for folders and the system Open/Save dialog) |
| Login | greetd with the Noctalia Greeter (wallpaper and palette synced from noctalia) |
| Theme | Tokyo Night, pushed to Hyprland/Ghostty/GTK by noctalia's templates |
| Font | JetBrainsMono Nerd Font |
| Kernel | CachyOS `linux-cachyos-bore` (BORE scheduler) with the prebuilt `linux-cachyos-bore-nvidia-580xx` module, x86-64-v3 repos |
| Boot | Limine (starry-night menu) booting a Unified Kernel Image built by mkinitcpio |
| Filesystem | btrfs, no snapshots (`zstd:1`, `noatime`); zram + a 32 GB swap file |

Built for a Ryzen 7 5800X with a GTX 980 (Maxwell, 4 GB), 1080p @ 60 Hz.

## Install

On a fresh Arch install (UEFI, btrfs, your user created, `base-devel` and `git` present).

**1. Stable repos only, then the CachyOS repositories.** CachyOS builds against stable Arch, so
the `[core-testing]`, `[extra-testing]` and `[multilib-testing]` repos must be disabled
(mixing them fails on OpenSSL: the forked pacman needs `libcrypto.so=3`). Then follow the manual steps in
the CachyOS wiki, [Optimized Repositories](https://wiki.cachyos.org/features/optimized_repos/):
import and sign the repository key, `pacman -U` the keyring and mirrorlists, add `[cachyos-v3]`,
`[cachyos-core-v3]`, `[cachyos-extra-v3]` and `[cachyos]` above the Arch repos, then `pacman -Syu`.
(x86-64-v3 is for CPUs that support it; check with `/lib/ld-linux-x86-64.so.2 --help | grep supported`.)

**2. The setup.**

```sh
git clone https://github.com/xynorash/xyno-arch.git ~/xyno-arch
cd ~/xyno-arch
./install.sh --packages --system   # packages, home symlinks, /etc files, services
```

`--packages` needs `yay` first (`git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si`);
without it only the pacman list is installed. The NVIDIA driver (580xx branch, for the GTX 980) comes
from the CachyOS repo as a prebuilt kernel module, so there is no DKMS build.

Existing files are moved to `*.bak-<timestamp>` rather than overwritten.
Paths use `$HOME`; the noctalia config is rewritten for your home if it differs.

### What stays manual (hardware-specific)

- **Disk layout:** btrfs with subvolumes `@` (/), `@home`, `@log`, `@pkg` and `@swap`
  (a 32 GB swapfile: `btrfs filesystem mkswapfile --size 32g /swap/swapfile`, priority 10 in fstab;
  zram is priority 100). Mount options for the btrfs entries: `noatime,compress=zstd:1,ssd,discard=async`.
- **Bootloader:** the kernel is one Unified Kernel Image per kernel, built by `mkinitcpio` from
  `mkinitcpio.d/linux-cachyos-bore.preset` into `/boot/EFI/Linux/cachyos-bore.efi`. Write
  `/etc/kernel/cmdline` with your own root `PARTUUID` (`blkid`), install `mkinitcpio.conf` and the
  preset by hand, then `sudo mkinitcpio -p linux-cachyos-bore`. The preset also builds a fallback image of the
  same kernel (`cachyos-bore-fallback.efi`, without autodetect) that Limine lists as a second entry.
- **Limine:** `sudo pacman -S limine`, then `sudo mkdir -p /boot/EFI/limine` and copy
  `/usr/share/limine/BOOTX64.EFI`, `system/boot/EFI/limine/limine.conf` and
  `wallpapers/starry-night-tokyo.png` (as `wallpaper.png`) into it. Register it without making it the
  default: `sudo efibootmgr --create-only --disk /dev/nvme0n1 --part 1 --label Limine --loader '\EFI\limine\BOOTX64.EFI'`,
  test once with `sudo efibootmgr --bootnext <number>`, and only after it boots put it first in `efibootmgr --bootorder`.
  `install.sh --system` installs a pacman hook that refreshes `BOOTX64.EFI` when the `limine` package updates.
- **Keyring:** make the login keyring the default and give it your login password,
  or `gh`/git will find it locked.
- **Login:** `noctalia-greeter` on greetd ([docs](https://docs.noctalia.dev/greeter/)). Write
  `/etc/greetd/config.toml` with `[terminal] vt = 1` and `[default_session]` `command = "/usr/bin/noctalia-greeter-session"`,
  `user = "greeter"`; run `sudo noctalia-greeter-apply-appearance --setup-system` (it does not touch PAM);
  set the default user, session `Hyprland`, keyboard and cursor in `/var/lib/noctalia-greeter/greeter.toml`;
  copy your cursor theme to `/usr/local/share/icons` (the greeter account cannot read `~/.local`); then
  `sudo systemctl enable greetd` and run Settings, Security, Noctalia Greeter, Sync Now once in the desktop.
  Copy `system/etc/pam.d/greetd` over `/etc/pam.d/greetd` (it adds GNOME Keyring unlock at login, replacing a package file by hand);
  the keyring must be named `login` and have your login password, or the unlock dialog comes back.
  To hide the UWSM session entry, add `NoExtract = usr/share/wayland-sessions/hyprland-uwsm.desktop` to `/etc/pacman.conf`.
- After first boot: `sudo tailscale up`, `gh auth login`, and `tools/install-strata.sh` for Strata.

## Layout

```
home/       dotfiles, symlinked into $HOME
system/     /etc and /boot files, copied by --system (boot files by hand)
wallpapers/ generated wallpaper (referenced by config.toml)
tools/      wallpaper and logo generators, Strata installer
packages/   explicit pacman and AUR package lists
```

## Keybindings

`Super + Shift + /` prints the full list in a floating terminal; it is parsed
straight out of `hyprland.lua`, so it can't go stale.

| Key | Action |
|---|---|
| `Super + T` | Terminal |
| `Super + E` | File manager (Strata) |
| `Super + D` | Launcher |
| `Super + Shift + D` | Docker (lazydocker in a terminal) |
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
- **BORE scheduler** from the CachyOS kernel; no user-space scheduler on top.
- **NVIDIA power limit** raised from 180 W to the card's 225 W maximum by a
  systemd unit (installed only when an NVIDIA GPU is present).
- **Direct scanout and tearing** for Steam windows only; the desktop stays
  tear-free. Once Human opens fullscreen so clicks line up.
- **MangoHud** with VRAM on screen (`Right Shift + F12`); the 4 GB card makes
  VRAM the number worth watching.
- **NTSYNC** module loaded for Wine builds that can use it.
- **Shader cache:** `__GL_SHADER_DISK_CACHE_SIZE` raised to 12 GB and cleanup skipped, set for the whole
  session in `hyprland.lua` (the NVIDIA driver otherwise prunes it and DXVK/VKD3D games recompile shaders).
- **Proton:** `proton-cachyos-slr` from the CachyOS repo (NTSYNC support); pick it per game or as the default
  under Steam's Settings, Compatibility. Steam's download tuning is in `home/.local/share/Steam/steam_dev.cfg`.

## Notes

- `hyprland.lua` uses the Lua config format. hyprlang (`hyprland.conf`) is
  deprecated as of Hyprland 0.55. The monitor is auto-detected.
- noctalia writes `noctalia.lua` and `settings.toml` itself;
  those are gitignored so generated files don't fight the repo. Everything that
  defines the look (palette, bar geometry, wallpaper, lock screen, widgets)
  lives in the tracked `config.toml`, which overrides nothing and is overridden
  by the state file only if you change the same setting through the GUI. What
  stays untracked is per-monitor widget placement.
- `system/etc/mkinitcpio.conf`, `system/etc/mkinitcpio.d/linux-cachyos-bore.preset`,
  `system/boot/EFI/limine/limine.conf` and `system/boot/loader/loader.conf` (systemd-boot, kept as a fallback) are **not** installed automatically. They
  replace files tied to the boot setup: diff them first, then run
  `sudo mkinitcpio -p linux-cachyos-bore`.
- Paths inside `hyprland.lua` and `noctalia/config.toml` are absolute
  (`/home/xynorash/...`). Adjust them for another username.
