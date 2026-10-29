
# The following lines were added by compinstall

zstyle ':completion:*' auto-description '%d'
zstyle ':completion:*' completer _complete _ignored _approximate
zstyle ':completion:*' expand prefix suffix
zstyle ':completion:*' file-sort name
zstyle ':completion:*' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' list-dirs-first true
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' list-colors 'di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' list-suffixes true
zstyle ':completion:*' matcher-list '' '+m:{[:lower:]}={[:upper:]}' '+r:|[._-]=** r:|=**' '+l:|=* r:|=*'
zstyle ':completion:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3)) numeric)'
zstyle ':completion:*' menu select=0
zstyle ':completion:*' original true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' squeeze-slashes true
zstyle :compinstall filename '/home/spirit/.config/zsh/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.config/zsh/.histfile
HISTSIZE=50000
SAVEHIST=50000
setopt autocd extendedglob nomatch notify
unsetopt beep
bindkey -v
# End of lines configured by zsh-newuser-install

# Prompt: vi mode, directory, git branch (and rebase/merge state), red %/# after a failed command
autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{magenta}%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}%b%f %F{red}(%a)%f'
add-zsh-hook precmd vcs_info

# Transient prompt: once a line is accepted, redraw its prompt as just %/#
# so scrollback shows only the commands
function zle-line-finish {
  PROMPT=$transient_prompt
  zle reset-prompt
  print -n '\e[0 q'    # give commands kitty's default cursor back
}
zle -N zle-line-finish
function restore-full-prompt { PROMPT=$full_prompt }
add-zsh-hook precmd restore-full-prompt

# Fill the rest of the info line with ─ up to the right edge
function prompt-fill {
  local info=${(%):-%~$vcs_info_msg_0_}
  info=${info//$'\e'\[[0-9;]#m/}    # strip colour codes before measuring
  local -i n=$(( COLUMNS - ${#info} - 1 ))
  (( n < 0 )) && n=0
  prompt_fill=${(pl:$n::─:)}
}
add-zsh-hook precmd prompt-fill
function TRAPWINCH {
  prompt-fill
  zle && zle reset-prompt
}

setopt prompt_subst
full_prompt=$'%F{blue}%~%f${vcs_info_msg_0_} %F{8}${prompt_fill}%f\n${vimode} %(?.%F{green}.%F{red})%#%f '
transient_prompt='%(?.%F{green}.%F{red})%#%f '
PROMPT=$full_prompt

# Completion like Neovim's: ^N/^P open the menu on the first/last match and
# move through it, ^Y accepts, ^E cancels and restores what was typed
zmodload zsh/complist
bindkey -M viins '^N' menu-complete
bindkey -M viins '^P' reverse-menu-complete
bindkey -M menuselect '^N' menu-complete
bindkey -M menuselect '^P' reverse-menu-complete
bindkey -M menuselect '^Y' accept-line
bindkey -M menuselect '^E' send-break

# Cache results of slow completions (pkg install <Tab> and the like)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/compcache

# History
setopt share_history        # every open shell sees commands from the others as they run
setopt extended_history     # store a timestamp and duration with each command
setopt hist_ignore_all_dups # repeating a command drops its older copy
setopt hist_ignore_space    # a command starting with a space isn't saved
setopt hist_reduce_blanks
setopt hist_verify          # !!, !$ etc. expand onto the line instead of running at once

# Up/Down (and k/j in normal mode) only walk through history entries that
# start with what's already typed; on an empty line they behave as usual
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey -M viins '^[[A' up-line-or-beginning-search
bindkey -M viins '^[[B' down-line-or-beginning-search
bindkey -M viins '^[OA' up-line-or-beginning-search
bindkey -M viins '^[OB' down-line-or-beginning-search
bindkey -M vicmd 'k' up-line-or-beginning-search
bindkey -M vicmd 'j' down-line-or-beginning-search

# Directories: every cd is pushed onto the directory stack, so cd -<Tab>
# offers a menu of recently visited directories
setopt auto_pushd pushd_ignore_dups pushd_silent
DIRSTACKSIZE=20

# Colours in FreeBSD's ls without needing -G
export CLICOLOR=1
export LESS_TERMCAP_mb=$'\e[1;31m'     # blink: bold red
export LESS_TERMCAP_md=$'\e[1;36m'     # bold (headings, commands): bold cyan
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;33;44m'  # standout (status line, search hits): yellow on blue
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;32m'     # underline (arguments, paths): underlined green
export LESS_TERMCAP_ue=$'\e[0m'
export GROFF_NO_SGR=1                  # keep groff's output in the same form, if it's ever used

# zmv: batch renames with patterns, e.g. zmv '(*).jpeg' '$1.jpg' (-n previews)
autoload -Uz zmv

# run-help: K in normal mode or Alt-h in insert mode shows help for the command
# being typed (man page, zsh builtin docs, or git/sudo subcommands) and keeps the line
(( $+aliases[run-help] )) && unalias run-help
autoload -Uz run-help run-help-git run-help-sudo
HELPDIR=/usr/local/share/zsh/$ZSH_VERSION/help
bindkey -M vicmd 'K' run-help
bindkey -M viins '^[h' run-help

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/pkg.zsh
source $ZDOTDIR/vi-mode.zsh

# Plugins

# fzf: ^R fuzzy history, ^T insert files, Alt-C cd into a directory
source <(fzf --zsh)

# Grey suggestion from history (or completion) as you type; → or ^F accepts it
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey -M viins '^F' autosuggest-accept

# Must stay last: it wraps every widget defined before it
source /usr/local/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
