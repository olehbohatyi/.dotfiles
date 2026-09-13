#!/usr/bin/env bash
# Install this repo's dotfiles on macOS/Linux via GNU Stow.
# See README.md ("Installing" section) for the full explanation.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PACKAGES=(bash zsh amm git cli)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--adopt] [package ...]

Symlinks this repo's config files into $HOME using GNU Stow.

  (no args)   Install all packages: bash zsh amm git cli
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

# Some tools keep machine-local runtime state in the same directory as their
# config. If that directory doesn't exist yet, stow symlinks the *whole*
# directory into the repo and everything the tool writes afterwards lands in
# git — Ammonite's history, cache/ and rt-*.jar files (hundreds of MB).
# Creating the directory first forces stow to fold into it instead, linking
# only the tracked files. Verified both ways against a scratch $HOME; see
# CLAUDE.md. Plain case/esac rather than an associative array so this still
# runs on the bash 3.2 that ships with macOS.
for pkg in "${packages[@]}"; do
  case "$pkg" in
    amm) mkdir -p "$HOME/.ammonite" ;;
  esac
done

if $adopt; then
  echo "Adopting existing files in \$HOME into the repo."
  stow --adopt -v -d "$DOTFILES_DIR" -t "$HOME" "${packages[@]}"
  echo "Run 'git diff' inside $DOTFILES_DIR now to see what was pulled in, and keep only what you want."
  exit 0
fi

# True for a package-relative path that stow will refuse to link, mirroring
# the patterns every package repeats in its .stow-local-ignore. The backup
# loop below has to agree with stow about this: it walks the package with
# find, so without this filter it treats amm/.gitignore as a file destined
# for ~/.gitignore, moves a real global gitignore into the backup dir, and
# then stow links nothing in its place. Verified against a scratch $HOME.
stow_ignored() {
  case "${1##*/}" in
    .stow-local-ignore|.gitignore|.gitmodules|.DS_Store|*~) return 0 ;;
  esac
  # Stow anchors these three at the package root, so match only a bare
  # filename — a hypothetical docs/README.md really would get linked.
  case "$1" in
    README*|LICENSE*|COPYING) return 0 ;;
  esac
  return 1
}

# Move any real (non-symlink) conflicting file out of the way so a machine
# that already has its own .bashrc/.zshrc/etc. doesn't lose it silently.
backed_up=false
for pkg in "${packages[@]}"; do
  [ -d "$DOTFILES_DIR/$pkg" ] || { echo "error: unknown package '$pkg'" >&2; exit 1; }
  while IFS= read -r -d '' file; do
    rel="${file#"$DOTFILES_DIR"/"$pkg"/}"
    target="$HOME/$rel"
    # `if` rather than `stow_ignored ... && continue`: under `set -e` a
    # trailing non-zero in an && list is not reliably exempt.
    if stow_ignored "$rel"; then continue; fi
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
      mv "$target" "$BACKUP_DIR/$rel"
      echo "backed up $target -> $BACKUP_DIR/$rel"
      backed_up=true
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
done

stow -v -d "$DOTFILES_DIR" -t "$HOME" "${packages[@]}"

# --add after checking, never a bare `git config include.path`: that form
# fails outright ("cannot overwrite multiple values with a single value") on
# any ~/.gitconfig that already has more than one include.path — a work +
# personal conditional-include setup, say. Under `set -euo pipefail` that
# aborted the script *after* stowing, so the run ended on a git error with no
# summary. Checking first also makes repeat runs idempotent instead of
# appending a duplicate include every time.
if [[ " ${packages[*]} " == *" git "* ]]; then
  if git config --global --get-all include.path 2>/dev/null | grep -qxF "$HOME/.aliases"; then
    echo "~/.aliases already registered in ~/.gitconfig (include.path)."
  else
    git config --global --add include.path "$HOME/.aliases"
    echo "Registered ~/.aliases in ~/.gitconfig (include.path)."
  fi
fi

if $backed_up; then
  echo
  echo "Some existing files were backed up to $BACKUP_DIR."
  echo "Diff them against the repo and hand-merge anything custom (see README.md)."
fi

echo
echo "Done. Restart your shell (or 'source ~/.bashrc' / 'exec zsh') to pick up the new config."
