git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

setopt PROMPT_SUBST

# Literal escapes rather than %F{n}, because %F consults terminfo: on a TERM
# whose entry advertises only 8 colors (plain `xterm`, `linux`, `xterm-color`)
# every index >= 8 silently degrades to %F{9} -> \e[39m, "default
# foreground", so the whole prompt renders colourless — while bash, which
# hardcodes the same bytes, stays coloured. SSH or tmux into such a terminal
# and the two shells stopped matching. These are the exact bytes .bashrc
# emits, so they now agree under every TERM.
#
# $'...' is ANSI-C quoting: it expands the \e escapes once at assignment but
# performs no command substitution, so $(git_branch) survives as literal text
# for PROMPT_SUBST to run at each redraw. %{ %} marks the enclosed bytes
# zero-width, the zsh equivalent of bash's \[ \].
if [[ $EUID -ne 0 ]]; then
  PROMPT=$'%{\e[0;96m%}λ %{\e[0;91m%}%n%{\e[0;96m%}: %{\e[0;93m%}%1~%{\e[0;94m%}$(git_branch) %{\e[0;92m%}∫ %{\e[0m%}'
else
  PROMPT=$'%{\e[0;31m%}%n %{\e[0;37m%}%1~%{\e[0;90m%}$(git_branch) %{\e[0;31m%}# %{\e[0m%}'
fi

# Modern CLI tool integration (bat/eza/fd/rg/zoxide), shared with bash.
[ -f "$HOME/.clirc" ] && . "$HOME/.clirc"
