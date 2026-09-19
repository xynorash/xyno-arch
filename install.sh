#!/usr/bin/env bash
# xyno-arch installer.
#
#   ./install.sh            symlink the home configs
#   ./install.sh --system   also install /etc + /boot files (needs sudo)
#
# Existing files are moved aside to <file>.bak-<timestamp>, never overwritten.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
stamp=$(date +%Y%m%d%H%M%S)
system=0
[[ ${1:-} == --system ]] && system=1

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
  backup "$dst"
  ln -s "$src" "$dst"
  echo "  $dst -> $src"
done < <(find "$repo/home" -type f -print0)

echo "installing the wallpaper"
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$repo/wallpapers/"*.png "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

if (( system )); then
  echo "installing system files (sudo)"
  for rel in etc/sysctl.d/99-zram.conf \
             etc/sysctl.d/99-network-tuning.conf \
             etc/security/limits.d/99-realtime-audio.conf \
             etc/modules-load.d/ntsync.conf \
             etc/scx_loader.toml \
             etc/greetd/config.toml \
             etc/systemd/system/nvidia-powerlimit.service; do
    sudo install -Dm644 "$repo/system/$rel" "/$rel"
    echo "  /$rel"
  done
  sudo sysctl --system >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now scx_loader.service nvidia-powerlimit.service
  echo "group membership"
  for g in gamemode seat docker; do
    getent group "$g" >/dev/null && sudo usermod -aG "$g" "$USER" && echo "  $USER -> $g"
  done

  echo "hostname in /etc/hosts"
  if ! grep -q '127.0.1.1' /etc/hosts; then
    sudo sed -i "/^127.0.0.1[[:space:]]*localhost/a 127.0.1.1        $(hostname).localdomain    $(hostname)" /etc/hosts
    echo "  added 127.0.1.1 $(hostname)"
  fi

  echo "services this setup does not want running"
  for u in cockpit.socket systemd-networkd-wait-online.service; do
    systemctl is-enabled "$u" &>/dev/null && sudo systemctl disable --now "$u" && echo "  disabled $u"
  done

  echo
  echo "not installed automatically, they replace files the system owns:"
  echo "  system/etc/pam.d/greetd        adds gnome-keyring unlock at login"
  echo "  system/etc/mkinitcpio.d/linux.preset  builds the fallback UKI as well"
  echo "  system/etc/mkinitcpio.conf     nvidia modules in MODULES, kms hook removed"
  echo "  system/etc/kernel/cmdline      kernel command line baked into the UKI"
  echo "  system/boot/loader/loader.conf systemd-boot (editor disabled, default pinned)"
  echo "compare them by hand, then run: sudo mkinitcpio -P"
fi

echo
echo "done. log out and back in for the session to pick everything up."
