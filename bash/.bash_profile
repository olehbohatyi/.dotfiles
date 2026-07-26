#!/usr/bin/env bash
# shellcheck shell=bash
#
# Login shells (e.g. macOS Terminal.app, TTY logins) source .bash_profile
# instead of .bashrc. Pull in .bashrc explicitly so login and non-login
# shells share the same prompt, functions, and aliases.

if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
