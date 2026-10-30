# Aliases: sourced from .zshrc

# extendedglob makes ^ and ~ special, which breaks HEAD^ / HEAD~2
alias git='noglob git'

# Git
alias gits='git status'
alias gita='git add'
alias gitaa='git add --all'
alias gitc='git commit -a'

alias e='$EDITOR'

alias ccf='cc -std=c17 -Wall -Wextra -pedantic -Werror -g -fsanitize=address,undefined'
