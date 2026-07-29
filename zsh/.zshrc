git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

setopt PROMPT_SUBST

if [[ $EUID -ne 0 ]]; then
  PROMPT='%F{14}λ %F{9}%n%F{14}: %F{11}%1~%F{12}$(git_branch) %F{10}∫%f '
else
  PROMPT='%F{1}%n %F{7}%1~%F{8}$(git_branch) %F{1}#%f '
fi

# Modern CLI tool integration (bat/eza/fd/rg/zoxide), shared with bash.
[ -f "$HOME/.clirc" ] && . "$HOME/.clirc"
