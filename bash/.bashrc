#!/usr/bin/env bash
# shellcheck shell=bash
#
# Interactive shell config, sourced directly by non-login shells and via
# .bash_profile for login shells (see bash/.bash_profile).

git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

if [ "$(id -u)" -ne 0 ]; then
  PS1="\e[0;96mλ \e[0;91m\u\e[0;96m: \e[0;93m\W\e[0;94m\$(git_branch) \e[0;92m∫ \e[0m"
else
  PS1="\e[0;31m\u \e[0m\W\e[0;90m\$(git_branch) \e[0;31m# \e[0m"
fi
export PS1

# Modern CLI tool integration (bat/eza/fd/rg/zoxide), shared with zsh.
[ -f "$HOME/.clirc" ] && . "$HOME/.clirc"
