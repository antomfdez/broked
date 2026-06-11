#!/bin/sh
# broked installer / updater. Safe to re-run; each run brings the install
# up to date.
#
#   sh install.sh             install (or update) into ~/.broked
#   BROKED_HOME=/opt/broked sh install.sh    ...or anywhere else
#
# The install directory IS a git clone of the repository
# all live in the one place. Updating is the same command: the script pulls
# and rebuilds. Uninstalling is `rm -rf ~/.broked`.
set -e

REPO_URL="${BROKED_REPO:-https://github.com/antomfdez/broked.git}"
HOME_DIR="${BROKED_HOME:-$HOME/.broked}"
SRC_FILE="$HOME_DIR/broked.bk"
OUT_FILE="$HOME_DIR/broked"

if [ -d "$HOME_DIR/.git" ]; then
  echo "broked: updating $HOME_DIR"
  git -C "$HOME_DIR" pull --ff-only
elif [ -e "$HOME_DIR" ]; then
  echo "broked: $HOME_DIR exists but is not a git clone - refusing to touch it." >&2
  echo "       Move it aside or set BROKED_HOME elsewhere." >&2
  exit 1
else
  echo "broked: cloning into $HOME_DIR"
  git clone "$REPO_URL" "$HOME_DIR"
fi

echo "broked: building"
brokm build "$SRC_FILE" -o "$OUT_FILE"

case ":$PATH:" in
  *":$HOME_DIR:"*) ;;
  *)
    echo ""
    echo "Add broked to your shell profile:"
    echo ""
    echo "  # bash/zsh (~/.bashrc, ~/.zshrc)"
    echo "  export PATH=\"\$BROKED_HOME:\$PATH\""
    echo ""
    echo "  # fish (~/.config/fish/config.fish)"
    echo "  fish_add_path $HOME_DIR"
    ;;
esac

echo ""
echo "broked: update any time by re-running this script."
