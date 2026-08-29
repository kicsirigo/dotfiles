#
# ~/.bashrc
#

[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
alias vscode='code .'
export MICRO_TRUECOLOR=1
fm6000 --random --color random --not-de

# Allow Lutris to use user-site packages (specifically our patch to fix Steam sync)
export LUTRIS_ALLOW_LOCAL_PYTHON_PACKAGES=1

