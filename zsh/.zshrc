git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

setopt PROMPT_SUBST

PROMPT='%F{14}λ %F{9}%n%F{14}: %F{11}%1~%F{12}$(git_branch) %F{10}∫%f '
