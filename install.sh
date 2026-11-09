#!/usr/bin/env bash
# xyno-arch installer.
#
#   ./install.sh            symlink the home configs
#   ./install.sh --system   also install the /etc files and enable services (needs sudo)
#   ./install.sh --packages install packages/pacman.txt (+ aur.txt via yay)
#                           first; combine with --system, e.g. --packages --system
#
# Existing files are moved aside to <file>.bak-<timestamp>, never overwritten.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
stamp=$(date +%Y%m%d%H%M%S)
system=0
packages=0
for arg in "$@"; do
  case $arg in
    --system)   system=1 ;;
    --packages) packages=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if (( packages )); then
  echo "installing packages (sudo)"
  sudo pacman -S --needed - < <(grep -vE '^\s*(#|$)' "$repo/packages/pacman.txt")
  if ! command -v yay &>/dev/null; then
    echo "  yay is not installed: build it from https://aur.archlinux.org/yay.git, then rerun with --packages"
  else
    yay -S --needed - < <(grep -vE '^\s*(#|$)' "$repo/packages/aur.txt")
  fi
fi

backup() {
  local target=$1
  if [[ -e $target && ! -L $target ]]; then
    mv "$target" "$target.bak-$stamp"
    echo "  kept old $target as $target.bak-$stamp"
  elif [[ -L $target ]]; then
    rm "$target"
  fi
}

echo "linking home configs"
while IFS= read -r -d '' src; do
  rel=${src#"$repo"/home/}
  dst=$HOME/$rel
  mkdir -p "$(dirname "$dst")"
  # a copy rewritten for another $HOME (see below) that is already current is left alone
  if [[ $HOME != /home/xynorash && $rel == .config/noctalia/config.toml && -f $dst && ! -L $dst ]] \
     && cmp -s <(sed "s|/home/xynorash|$HOME|g" "$src") "$dst"; then
    echo "  $dst is current"; continue
  fi
  backup "$dst"
  ln -s "$src" "$dst"
  echo "  $dst -> $src"
done < <(find "$repo/home" -type f -print0)

# noctalia's TOML cannot expand $HOME; if this is not the original home, swap
# the symlink for a copy with the path rewritten.
if [[ $HOME != /home/xynorash ]]; then
  for rel in .config/noctalia/config.toml; do
    rm -f "$HOME/$rel"
    sed "s|/home/xynorash|$HOME|g" "$repo/home/$rel" > "$HOME/$rel"
    echo "  $HOME/$rel rewritten for $HOME"
  done
fi

echo "installing the wallpaper"
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$repo/wallpapers/"*.png "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

if (( system )); then
  echo "installing system files (sudo)"
  files=(etc/sysctl.d/99-zram.conf
         etc/systemd/zram-generator.conf
         etc/sysctl.d/99-network-tuning.conf
         etc/security/limits.d/99-realtime-audio.conf
         etc/modules-load.d/ntsync.conf
         etc/modules-load.d/nct6775.conf
         etc/default/earlyoom
         etc/systemd/logind.conf.d/10-power-key.conf
         etc/systemd/network/20-ethernet.network
         etc/tmpfiles.d/10-thp-madvise.conf
         etc/pacman.d/hooks/limine-update.hook)
  # the power-limit unit only makes sense with an NVIDIA GPU (it fails, and would stop this script, without one)
  nvidia=0
  if command -v nvidia-smi &>/dev/null && lspci 2>/dev/null | grep -qi 'vga.*nvidia\|3d.*nvidia'; then
    nvidia=1
    files+=(etc/systemd/system/nvidia-powerlimit.service)
  fi
  for rel in "${files[@]}"; do
    sudo install -Dm644 "$repo/system/$rel" "/$rel"
    echo "  /$rel"
  done
  sudo sysctl --system >/dev/null
  sudo systemd-tmpfiles --create /etc/tmpfiles.d/10-thp-madvise.conf
  sudo systemctl daemon-reload
  sudo systemctl reload systemd-logind
  sudo systemctl enable --now earlyoom.service
  if (( nvidia )); then sudo systemctl enable --now nvidia-powerlimit.service; fi
  echo "base services"
  sudo systemctl enable tailscaled.service \
       systemd-networkd.service systemd-resolved.service systemd-timesyncd.service
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  echo "group membership"
  for g in gamemode docker uucp video render kvm input; do
    getent group "$g" >/dev/null && sudo usermod -aG "$g" "$USER" && echo "  $USER -> $g"
  done

  echo "hostname in /etc/hosts"
  if ! grep -q '127.0.1.1' /etc/hosts; then
    sudo sed -i "/^127.0.0.1[[:space:]]*localhost/a 127.0.1.1        $(hostname).localdomain    $(hostname)" /etc/hosts
    echo "  added 127.0.1.1 $(hostname)"
  fi

  echo "services this setup does not want running"
  if systemctl is-enabled systemd-networkd-wait-online.service &>/dev/null; then
    sudo systemctl disable --now systemd-networkd-wait-online.service && echo "  disabled systemd-networkd-wait-online.service"
  fi

  echo
  echo "not installed automatically, they are tied to the boot setup of one machine:"
  echo "  system/etc/mkinitcpio.conf                          nvidia modules in MODULES, kms hook removed"
  echo "  system/etc/mkinitcpio.d/linux-cachyos-bore.preset   builds the CachyOS kernel's boot image (UKI)"
  echo "  system/boot/loader/loader.conf                      systemd-boot, default = cachyos-bore.efi, editor off"
  echo "  /etc/kernel/cmdline is not in the repo: it holds your root PARTUUID (blkid), e.g."
  echo "    root=PARTUUID=<yours> zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"
  echo "compare them by hand, then run: sudo mkinitcpio -p linux-cachyos-bore"
  echo
  echo "login screen: noctalia-greeter comes from packages/pacman.txt; set it up by hand (README, \"Login\")"
fi

echo
echo "done. log out and back in for the session to pick everything up."
