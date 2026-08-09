#!/usr/bin/env bash
#
# Checks for this repo. Runs the syntax checks CLAUDE.md documents, plus a
# regression test for each bug that has actually bitten here — the prompt
# invariants, the path-splitting traps, and the two installer failures that
# only showed up against a scratch $HOME.
#
# Usage: ./test.sh
#
# No arguments, no network, no writes outside a temp dir. Optional tools
# (zsh, pwsh, amm) are skipped with a note rather than failing, so this is
# safe to run on a machine that doesn't have all four shells.
#
# Deliberately not `set -e`: every check should run even after one fails, so
# a single break doesn't hide the rest.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

passed=0
failed=0
skipped=0

ok()   { printf '  \033[0;92mok\033[0m      %s\n' "$1"; passed=$((passed + 1)); }
bad()  { printf '  \033[0;91mFAIL\033[0m    %s\n' "$1"; failed=$((failed + 1)); }
skip() { printf '  \033[0;90mskip\033[0m    %s\n' "$1"; skipped=$((skipped + 1)); }
group(){ printf '\n\033[0;93m%s\033[0m\n' "$1"; }

check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

# ---------------------------------------------------------------------------
group "Syntax"

check "bash: .bashrc .bash_profile .clirc install.sh test.sh" \
  bash -n bash/.bashrc bash/.bash_profile cli/.clirc install.sh test.sh

if command -v zsh >/dev/null 2>&1; then
  check "zsh: .zshrc .clirc" zsh -n zsh/.zshrc cli/.clirc
else
  skip "zsh not installed"
fi

if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -Command '
      $e = $null; $t = $null
      [System.Management.Automation.Language.Parser]::ParseFile(
        "pwsh/profile.ps1", [ref]$t, [ref]$e) | Out-Null
      if ($e.Count -ne 0) { $e; exit 1 }' >/dev/null 2>&1; then
    ok "pwsh: profile.ps1"
  else
    bad "pwsh: profile.ps1"
  fi
else
  skip "pwsh not installed"
fi

# ---------------------------------------------------------------------------
group "Prompt invariants"

# Both shells now spell the colours as literal \e[...m, so the same extraction
# works on both files and the two lists must match exactly. Order matters:
# line 1 is the normal prompt, line 2 the root one.
codes_on_line() { printf '%s' "$1" | grep -oE '\\e\[[0-9;]+m' | tr -d '\\' | tr '\n' ' '; }

bash_prompts=(); zsh_prompts=()
while IFS= read -r l; do bash_prompts+=("$l"); done < <(grep -E '^\s*PS1=' bash/.bashrc)
while IFS= read -r l; do zsh_prompts+=("$l"); done < <(grep -E '^\s*PROMPT=' zsh/.zshrc)

if [ "${#bash_prompts[@]}" -eq 2 ] && [ "${#zsh_prompts[@]}" -eq 2 ]; then
  for i in 0 1; do
    label=$([ "$i" = 0 ] && echo "normal" || echo "root")
    b="$(codes_on_line "${bash_prompts[$i]}")"
    z="$(codes_on_line "${zsh_prompts[$i]}")"
    if [ -n "$b" ] && [ "$b" = "$z" ]; then
      ok "$label prompt: bash and zsh use the same colours ($b)"
    else
      bad "$label prompt colours differ — bash:[$b] zsh:[$z]"
    fi
  done
else
  bad "expected 2 PS1 and 2 PROMPT lines, found ${#bash_prompts[@]} and ${#zsh_prompts[@]}"
fi

# Unwrapped escapes make readline miscount the line width; see CLAUDE.md.
for l in "${bash_prompts[@]:-}"; do
  [ -n "$l" ] || continue
  stripped="$(printf '%s' "$l" | sed -E 's/\\\[[^]]*\\\]//g')"
  case "$stripped" in
    *'\e['*) bad "bash prompt has an escape outside \\[ \\]: $l" ;;
    *)       ok  "bash prompt: all escapes wrapped in \\[ \\]" ;;
  esac
done

for l in "${zsh_prompts[@]:-}"; do
  [ -n "$l" ] || continue
  stripped="$(printf '%s' "$l" | sed -E 's/%\{[^}]*%\}//g')"
  case "$stripped" in
    *'\e['*) bad "zsh prompt has an escape outside %{ %}: $l" ;;
    *)       ok  "zsh prompt: all escapes wrapped in %{ %}" ;;
  esac
done

# %F{n} consults terminfo and collapses to \e[39m on an 8-colour TERM, so the
# prompt must not go back to it. Checked against the PROMPT lines only — the
# surrounding comments explain the trap and naturally mention %F{n}.
if printf '%s\n' "${zsh_prompts[@]:-}" | grep -qE '%F\{'; then
  bad "zsh/.zshrc uses %F{n} — degrades to no colour on an 8-colour TERM"
else
  ok "zsh prompt avoids %F{n}"
fi

if command -v zsh >/dev/null 2>&1; then
  # The literal form must emit identical bytes regardless of TERM.
  ref=""; term_ok=true
  for t in xterm-256color xterm screen linux dumb; do
    got="$(TERM=$t zsh -c 'source ./zsh/.zshrc >/dev/null 2>&1; print -rn -- "${(%)PROMPT}"' 2>/dev/null | od -An -c | tr -s ' ')"
    [ -z "$ref" ] && ref="$got"
    [ "$got" = "$ref" ] || term_ok=false
  done
  $term_ok && ok "zsh prompt renders identically under every TERM" \
           || bad "zsh prompt changes with TERM"

  # $'...' must leave $(git_branch) for PROMPT_SUBST to run per redraw.
  if zsh -c 'source ./zsh/.zshrc >/dev/null 2>&1; case "$PROMPT" in *"\$(git_branch)"*) exit 0;; esac; exit 1' 2>/dev/null; then
    ok "zsh prompt keeps \$(git_branch) unexpanded for PROMPT_SUBST"
  else
    bad "zsh prompt expanded \$(git_branch) at assignment — branch will be frozen"
  fi
else
  skip "zsh TERM and PROMPT_SUBST checks (zsh not installed)"
fi

# The two shells carry their own copy of git_branch (it cannot live in
# cli/.clirc, which is sourced conditionally), so they can drift apart.
bash_fn="$(sed -n '/^git_branch() {/,/^}/p' bash/.bashrc)"
zsh_fn="$(sed -n '/^git_branch() {/,/^}/p' zsh/.zshrc)"
if [ -n "$bash_fn" ] && [ "$bash_fn" = "$zsh_fn" ]; then
  ok "git_branch is identical in bash/.bashrc and zsh/.zshrc"
else
  bad "git_branch has drifted between bash/.bashrc and zsh/.zshrc"
fi

# `git branch | sed` costs a second process and disagrees with pwsh and
# Ammonite on a detached HEAD.
if printf '%s' "$bash_fn" | grep -q 'rev-parse'; then
  ok "git_branch resolves the branch with rev-parse"
else
  bad "git_branch is not using rev-parse"
fi

# All four prompts must render a detached HEAD the same way.
if command -v zsh >/dev/null 2>&1; then
  det="$TMPROOT/detached"
  mkdir -p "$det"
  ( cd "$det" \
    && git init -q . \
    && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m x \
    && git checkout -q --detach HEAD ) >/dev/null 2>&1
  want=" ($(cd "$det" && git rev-parse --short HEAD))"
  got_bash="$(cd "$det" && bash -c "source $DOTFILES_DIR/bash/.bashrc >/dev/null 2>&1; git_branch" 2>/dev/null)"
  got_zsh="$(cd "$det" && zsh -c "source $DOTFILES_DIR/zsh/.zshrc >/dev/null 2>&1; git_branch" 2>/dev/null)"
  if [ "$got_bash" = "$want" ] && [ "$got_zsh" = "$want" ]; then
    ok "detached HEAD shows the short SHA in both shells ($want)"
  else
    bad "detached HEAD differs — want:[$want] bash:[$got_bash] zsh:[$got_zsh]"
  fi
else
  skip "detached HEAD check (zsh not installed)"
fi

# ---------------------------------------------------------------------------
group "Path-splitting traps"

# os-lib's .baseName and .NET's BaseName both read a dotfile name as pure
# extension and return "", blanking the prompt's directory.
#
# Whole-line comments are stripped first, because the code carries comments
# warning about these very names. Line-based, so a trailing comment on a code
# line would still count — fine here, and far safer than stripping from the
# first `#`, which would eat the `#` sigil in profile.ps1's root prompt.
uncommented() { grep -vE "^[[:space:]]*$1" "$2"; }

if uncommented '//' amm/.ammonite/predef.sc | grep -qE '\.baseName'; then
  bad "amm predef uses .baseName — returns \"\" for a name like .dotfiles"
else
  ok "amm predef uses .last, not .baseName"
fi

if uncommented '#' pwsh/profile.ps1 | grep -qE '\)\.BaseName|Get-Item.*BaseName'; then
  bad "profile.ps1 uses .BaseName — returns \"\" for a name like .dotfiles"
else
  ok "profile.ps1 uses Split-Path -Leaf, not .BaseName"
fi

# ---------------------------------------------------------------------------
group "Stow ignore files"

# A package-local .stow-local-ignore replaces stow's built-in list rather than
# extending it, so each package repeats the full pattern set. claude/ is the
# one intentional exception: it is an allowlist.
ref_ignore="bash/.stow-local-ignore"
for f in */.stow-local-ignore; do
  case "$f" in claude/*) continue ;; esac
  if cmp -s "$ref_ignore" "$f"; then
    ok "$f matches $ref_ignore"
  else
    bad "$f has drifted from $ref_ignore"
  fi
done

# The allowlist only works if .claude/ is un-ignored before settings.json is
# re-included — git will not descend into an excluded directory.
if grep -qE '^\!\.claude/$' claude/.gitignore && grep -qE '^\!\.claude/settings\.json$' claude/.gitignore; then
  ok "claude/.gitignore un-ignores .claude/ before settings.json"
else
  bad "claude/.gitignore allowlist is missing a step"
fi

# Same allowlist shape for amm — the fold guard is the real protection, this
# is the backstop that keeps rt-*.jar out of git if the guard is ever lost.
if grep -qE '^\!\.ammonite/$' amm/.gitignore && grep -qE '^\!\.ammonite/predef\.sc$' amm/.gitignore; then
  ok "amm/.gitignore un-ignores .ammonite/ before the scripts"
else
  bad "amm/.gitignore allowlist is missing a step"
fi

# Functional check, not just a grep: the tracked scripts stay visible and the
# runtime state stays ignored.
allow_ok=true
for f in amm/.ammonite/predef.sc amm/.ammonite/helper.sc amm/.ammonite/import.sc; do
  git check-ignore -q "$f" 2>/dev/null && allow_ok=false
done
for f in amm/.ammonite/history amm/.ammonite/rt-25.0.3.jar amm/.ammonite/cache/x; do
  git check-ignore -q "$f" 2>/dev/null || allow_ok=false
done
$allow_ok && ok "amm allowlist: scripts tracked, runtime state ignored" \
          || bad "amm allowlist does not classify files correctly"

# ---------------------------------------------------------------------------
group "Installer (against a scratch \$HOME)"

# Stow only folds into a directory that already exists; otherwise it symlinks
# the whole thing into the repo and the tool's runtime state lands in git.
for pkg in claude amm; do
  h="$TMPROOT/fold-$pkg"; mkdir -p "$h"
  HOME="$h" ./install.sh "$pkg" >/dev/null 2>&1
  case "$pkg" in
    claude) d="$h/.claude" ;;
    amm)    d="$h/.ammonite" ;;
  esac
  if [ -d "$d" ] && [ ! -L "$d" ]; then
    ok "$pkg: target stays a real directory (folded, not whole-dir symlink)"
  else
    bad "$pkg: $d is a symlink — runtime state would be written into the repo"
  fi
done

# Files stow ignores must not be swept into the backup dir, or a real global
# ~/.gitignore disappears and nothing is linked in its place.
h="$TMPROOT/gitignore"; mkdir -p "$h"
printf 'node_modules/\n' > "$h/.gitignore"
HOME="$h" ./install.sh claude >/dev/null 2>&1
if [ -f "$h/.gitignore" ] && [ ! -L "$h/.gitignore" ] && grep -q node_modules "$h/.gitignore"; then
  ok "a real ~/.gitignore survives installing claude"
else
  bad "~/.gitignore was moved aside for a link that never comes"
fi

# A ~/.gitconfig with two include.path values used to abort the run after
# stowing, because plain `git config include.path` cannot overwrite a
# multi-valued key.
h="$TMPROOT/include"; mkdir -p "$h"
printf '[include]\n\tpath = /tmp/work\n[include]\n\tpath = /tmp/personal\n' > "$h/.gitconfig"
if HOME="$h" ./install.sh git >/dev/null 2>&1; then
  ok "install.sh git survives a multi-valued include.path"
else
  bad "install.sh git aborts on a multi-valued include.path"
fi

# Re-running must not append the include again.
HOME="$h" ./install.sh git >/dev/null 2>&1
n="$(HOME="$h" git config --global --get-all include.path 2>/dev/null | grep -cxF "$h/.aliases")"
if [ "$n" = "1" ]; then
  ok "repeat runs keep exactly one ~/.aliases include"
else
  bad "include.path registered $n times after two runs"
fi

# Nothing stow ignores may ever reach $HOME.
h="$TMPROOT/leak"; mkdir -p "$h"
HOME="$h" ./install.sh >/dev/null 2>&1
leaked="$(find "$h" -maxdepth 2 \( -name '.DS_Store' -o -name '.stow-local-ignore' -o -name '.gitignore' \) 2>/dev/null)"
if [ -z "$leaked" ]; then
  ok "no ignore files or .DS_Store linked into \$HOME"
else
  bad "leaked into \$HOME: $(printf '%s' "$leaked" | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
printf '\n%s\n' "-----------------------------------------------"
printf '%d passed, %d failed, %d skipped\n' "$passed" "$failed" "$skipped"
[ "$failed" -eq 0 ] || exit 1
