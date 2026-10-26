HISTFILE=~/.local/state/zsh/history   # zsh saves no history unless this is set
SAVEHIST=10000 HISTSIZE=10000
autoload -Uz compinit && compinit -d ~/.cache/zsh/zcompdump   # else .zcompdump lands in ZDOTDIR
