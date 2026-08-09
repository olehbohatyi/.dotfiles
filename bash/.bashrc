#!/usr/bin/env bash
# shellcheck shell=bash
#
# Interactive shell config, sourced directly by non-login shells and via
# .bash_profile for login shells (see bash/.bash_profile).

# Kept byte-identical to the copy in zsh/.zshrc — and matching what
# pwsh/profile.ps1 and amm/.ammonite/predef.sc ask git for, so all four
# prompts agree on a detached HEAD instead of the shells alone printing
# "((HEAD detached at abc1234))".
#
# One `git rev-parse` rather than `git branch | sed`: no second process, and
# no cost that scales with the number of branches. Deliberately not moved
# into cli/.clirc, which is sourced conditionally — a missing .clirc would
# leave the prompt calling a function that does not exist.
git_branch() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 0
  if [ "$branch" = "HEAD" ]; then
    branch=$(git rev-parse --short HEAD 2>/dev/null) || return 0
  fi
  [ -n "$branch" ] && printf ' (%s)' "$branch"
  return 0
}

# Every escape sequence is wrapped in \[ \]. Those delimiters are how bash
# tells readline "these bytes take up no columns"; without them readline
# counts all 46 escape bytes as printable and thinks an 80-column terminal
# has 1 usable column instead of 47, which corrupts wrapping on long lines
# and redraws during Ctrl-R. zsh's %{ %} below does the same job, and pwsh
# sidesteps it by writing the prompt with Write-Host instead of a string.
if [ "$(id -u)" -ne 0 ]; then
  PS1="\[\e[0;96m\]λ \[\e[0;91m\]\u\[\e[0;96m\]: \[\e[0;93m\]\W\[\e[0;94m\]\$(git_branch) \[\e[0;92m\]∫ \[\e[0m\]"
else
  PS1="\[\e[0;31m\]\u \[\e[0;37m\]\W\[\e[0;90m\]\$(git_branch) \[\e[0;31m\]# \[\e[0m\]"
fi
export PS1

# Modern CLI tool integration (bat/eza/fd/rg/zoxide), shared with zsh.
[ -f "$HOME/.clirc" ] && . "$HOME/.clirc"
