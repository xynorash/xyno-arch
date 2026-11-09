#!/usr/bin/env bash
# Install the Strata file manager (https://stratafiles.io, github.com/lgse/strata)
# for the current user and make it the default for folders.
#
#   tools/install-strata.sh [version]      default: 1.0.0
#
# Downloads the release archive, checks its SHA-256, and installs by hand
# instead of piping the project's install.sh into a shell:
#   ~/.local/bin/strata, the desktop entry and icon, and the D-Bus service that
#   answers "show in folder" requests from browsers and GTK apps.
# Then sets inode/directory to Strata. Runtime libraries come from
# packages/pacman.txt. Re-running upgrades in place.
set -euo pipefail

version=${1:-1.0.0}
target=x86_64-unknown-linux-gnu
name=strata-$version-$target
base=https://github.com/lgse/strata/releases/download/v$version

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

echo "downloading $name"
curl -fsSL -O "$base/$name.tar.gz" -O "$base/$name.tar.gz.sha256"
sha256sum --check "$name.tar.gz.sha256"
# The checksum comes from the same release page, so it proves the download is
# intact, not who built it. With GitHub CLI logged in, also check provenance:
if gh auth status >/dev/null 2>&1; then
  gh attestation verify "$name.tar.gz" --repo lgse/strata || { echo "attestation failed" >&2; exit 1; }
else
  echo "note: gh is not logged in, skipping the provenance check"
fi
tar -xzf "$name.tar.gz"
src=$work/$name

bin=$HOME/.local/bin
apps=$HOME/.local/share/applications
install -Dm755 "$src/strata" "$bin/strata"
install -Dm644 "$src/io.github.lgse.Strata.svg" \
  "$HOME/.local/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg"
install -d "$apps"
sed "s|^Exec=strata |Exec=$bin/strata |" "$src/io.github.lgse.Strata.desktop" \
  > "$apps/io.github.lgse.Strata.desktop"
install -d "$HOME/.local/share/dbus-1/services"
sed "s|^Exec=/usr/bin/strata|Exec=$bin/strata|" "$src/io.github.lgse.Strata.FileManager1.service" \
  > "$HOME/.local/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service"

# Open/Save dialogs: register Strata as an xdg-desktop-portal FileChooser backend. Strata's own settings
# toggle refuses to run when the portal config is a symlink (ours points into this repo), so do it here.
# The matching config line lives in home/.config/xdg-desktop-portal/hyprland-portals.conf:
#   org.freedesktop.impl.portal.FileChooser=strata;gtk;
install -d "$HOME/.local/share/xdg-desktop-portal/portals"
printf '[portal]\nDBusName=org.freedesktop.impl.portal.desktop.strata\nInterfaces=org.freedesktop.impl.portal.FileChooser;\n' \
  > "$HOME/.local/share/xdg-desktop-portal/portals/strata.portal"
printf '[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.strata\nExec=%s/strata --portal\n' "$bin" \
  > "$HOME/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service"
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true

update-desktop-database "$apps"
gtk-update-icon-cache -qtf "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
xdg-mime default io.github.lgse.Strata.desktop inode/directory

echo "installed: $("$bin/strata" --version)"
echo "default for folders: $(xdg-mime query default inode/directory)"
