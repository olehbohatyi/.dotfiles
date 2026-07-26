#!/usr/bin/env bash

if [ $(id -u) -ne 0 ];
then
  PS1="\e[0;96mλ \e[0;91m\u\e[0;96m: \e[0;93m\W\e[0;90m"'`__git_ps1`'" \e[0;92m∫ \e[0m"
else
  PS1="\e[0;31m\u \e[0;90m\w \e[0;31m# \e[0m"
fi
