git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export PS1="\e[0;96mλ \e[0;91m\u\e[0;96m: \e[0;93m\W\e[0;94m\$(git_branch) \e[0;92m∫ \e[0m"
