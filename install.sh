#!/usr/bin/env bash
# Install this repo's dotfiles on macOS/Linux via GNU Stow.
# See README.md ("Installing" section) for the full explanation.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PACKAGES=(bash zsh amm git)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--adopt] [package ...]

Symlinks this repo's config files into $HOME using GNU Stow.

  (no args)   Install all packages: bash zsh amm git
  package...  Install only the named packages, e.g. ./install.sh zsh git
  --adopt     Pull existing real files already in $HOME into the repo
              instead of backing them up. Use this when you want to keep
              whatever is already configured on THIS machine and fold it
              into the repo (review with `git diff` right after). See
              "Merging into an existing system" in README.md first.

Default behavior (no --adopt): any plain file already at the target path
(i.e. not already a symlink) is moved to
  ~/.dotfiles-backup/<timestamp>/
before stow runs, so nothing already on the machine is ever silently
overwritten. This is the safe choice for a system that already has its own
.bashrc/.zshrc/profile.ps1 etc.

pwsh/profile.ps1 is intentionally not a stow package here — Windows
PowerShell profile paths vary by PowerShell version/OS, so it has its own
installer: install.ps1 (run from pwsh or Windows PowerShell).
EOF
}

command -v stow >/dev/null 2>&1 || {
  echo "error: GNU Stow is not installed." >&2
  echo "  macOS:          brew install stow" >&2
  echo "  Debian/Ubuntu:  sudo apt install stow" >&2
  echo "  Fedora:         sudo dnf install stow" >&2
  exit 1
}

adopt=false
selected=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --adopt) adopt=true ;;
    *) selected+=("$arg") ;;
  esac
done

packages=("${DEFAULT_PACKAGES[@]}")
[ ${#selected[@]} -gt 0 ] && packages=("${selected[@]}")

if $adopt; then
  echo "Adopting existing files in \$HOME into the repo."
  stow --adopt -v -d "$DOTFILES_DIR" -t "$HOME" "${packages[@]}"
  echo "Run 'git diff' inside $DOTFILES_DIR now to see what was pulled in, and keep only what you want."
  exit 0
fi

# Move any real (non-symlink) conflicting file out of the way so a machine
# that already has its own .bashrc/.zshrc/etc. doesn't lose it silently.
backed_up=false
for pkg in "${packages[@]}"; do
  [ -d "$DOTFILES_DIR/$pkg" ] || { echo "error: unknown package '$pkg'" >&2; exit 1; }
  while IFS= read -r -d '' file; do
    rel="${file#"$DOTFILES_DIR"/"$pkg"/}"
    target="$HOME/$rel"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
      mv "$target" "$BACKUP_DIR/$rel"
      echo "backed up $target -> $BACKUP_DIR/$rel"
      backed_up=true
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
done

stow -v -d "$DOTFILES_DIR" -t "$HOME" "${packages[@]}"

if [[ " ${packages[*]} " == *" git "* ]]; then
  git config --global include.path "$HOME/.aliases"
  echo "Registered ~/.aliases in ~/.gitconfig (include.path)."
fi

if $backed_up; then
  echo
  echo "Some existing files were backed up to $BACKUP_DIR."
  echo "Diff them against the repo and hand-merge anything custom (see README.md)."
fi

echo
echo "Done. Restart your shell (or 'source ~/.bashrc' / 'exec zsh') to pick up the new config."
