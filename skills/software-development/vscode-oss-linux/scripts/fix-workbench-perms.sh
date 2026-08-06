#!/usr/bin/env bash
# Re-grant the user write access to VSCode's workbench dir (injection extensions
# like shalldie.background rewrite workbench.html there). Must be re-run after
# every `pacman -Syu` that upgrades the `code` package (ownership resets to root).
# Usage: bash fix-workbench-perms.sh   (no sudo password on stdin — uses askpass)
set -euo pipefail

ASKPASS="${SUDO_ASKPASS:-$HOME/.hermes/askpass.sh}"
if [[ ! -x "$ASKPASS" ]]; then
  echo "askpass helper missing/not executable, fixing: $ASKPASS"
  chmod +x "$ASKPASS"
fi

DIR="/usr/lib/code/out/vs/code/electron-browser/workbench"
SUDO_ASKPASS="$ASKPASS" sudo -A chown -R "$USER:$USER" "$DIR"
echo "chown OK: $DIR -> $USER"
ls -la "$DIR/workbench.html"
echo "Now fully restart VSCode (kill the process) so the extension re-injects."
