# Vi mode: sourced from .zshrc (bindkey -v itself is in the zsh-newuser-install block)

# Mode indicator for the prompt ($vimode) and cursor shape per mode
vimode='%F{green}I%f'
function zle-line-init zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    vimode='%F{yellow}N%f'
    print -n '\e[2 q'    # block cursor
  else
    vimode='%F{green}I%f'
    print -n '\e[6 q'    # beam cursor
  fi
  zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select
KEYTIMEOUT=1    # switch to normal mode right after Esc instead of waiting 0.4s

# In vi insert mode, Backspace, ^W and ^U normally stop at the point where
# insert mode was entered; make them delete freely like in emacs mode
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^U' backward-kill-line

# v in normal mode opens the command line in $EDITOR (nvim); :wq runs it.
# V still starts linewise visual mode
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# Text objects for operators and visual mode: ci" da( yi{ vib and so on
autoload -Uz select-quoted select-bracketed
zle -N select-quoted
zle -N select-bracketed
for m in viopp visual; do
  for c in {a,i}{\',\",\`}; do
    bindkey -M $m $c select-quoted
  done
  for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
    bindkey -M $m $c select-bracketed
  done
done

# iq/aq: the innermost quotes of any kind around the cursor, ib/ab: the
# innermost (), [] or {}; if the cursor isn't inside one, the next one on the line
# Sets REPLY to the quote (q) or opening bracket (b) of the pair to use
function vi-pick-pair {
  local fn c
  local -a chars
  if [[ $1 == q ]]; then
    fn=select-quoted chars=(\' \" \`)
  else
    fn=select-bracketed chars=('(' '[' '{')
  fi
  local -i cur=CURSOR mark=MARK active=REGION_ACTIVE enc bestenc=-1 span bestspan bestmark
  REPLY=
  for c in $chars; do
    CURSOR=$cur MARK=$mark REGION_ACTIVE=$active
    $fn "a$c" || continue
    (( enc = MARK <= cur && cur < CURSOR, span = CURSOR - MARK ))
    if (( enc > bestenc || (enc == bestenc && (enc ? span < bestspan : MARK < bestmark)) )); then
      REPLY=$c bestenc=$enc bestspan=$span bestmark=$MARK
    fi
  done
  CURSOR=$cur MARK=$mark REGION_ACTIVE=$active
  [[ -n $REPLY ]]
}
function select-any {
  local REPLY
  vi-pick-pair ${KEYS[2]} || return 1
  if [[ $REPLY == '(' || $REPLY == '[' || $REPLY == '{' ]]; then
    select-bracketed "${KEYS[1]}$REPLY"
  else
    select-quoted "${KEYS[1]}$REPLY"
  fi
}
zle -N select-any-quote select-any
zle -N select-any-bracket select-any
for m in viopp visual; do
  bindkey -M $m iq select-any-quote aq select-any-quote
  bindkey -M $m ib select-any-bracket ab select-any-bracket
done

# vim-surround: cs"' changes quotes, ds( deletes brackets, ysiw" adds quotes,
# S" surrounds a visual selection. q and b work as the old surrounding too.
# Based on zsh's surround widget, which can't be used directly: it picks its
# action from $WIDGET, and that stays the caller's name when invoked from the
# d/c/y wrapper below

# Sets reply=(opening closing) for a new surrounding typed as $1; an opening
# bracket pads with spaces, a closing one doesn't
function vi-surround-pair {
  local -A matching=( \( \) \{ \} \< \> \[ \] )
  if [[ -n $matching[$1] ]]; then
    reply=("$1 " " $matching[$1]")
  elif [[ -n $matching[(r)[$1:q]] ]]; then
    reply=("${(k)matching[(r)[$1:q]]}" "$1")
  else
    reply=("$1" "$1")
  fi
}

# Reads the surrounding character (q/b resolved) and selects it with "a"
function vi-select-surrounding {
  local t REPLY
  read -k 1 t
  if [[ $t == [qb] ]]; then
    vi-pick-pair $t || return 1
    t=$REPLY
  fi
  if [[ $t == [\(\)\[\]\{\}\<\>] ]]; then
    select-bracketed "a$t"
  else
    select-quoted "a$t"
  fi
}
function vi-delete-surround {
  zle -f vichange
  local -i cur=CURSOR
  vi-select-surrounding || { CURSOR=$cur; return 1 }
  BUFFER[CURSOR]=''
  BUFFER[MARK+1]=''
  CURSOR=MARK
}
function vi-change-surround {
  zle -f vichange
  local -i cur=CURSOR
  local new
  local -a reply
  vi-select-surrounding || { CURSOR=$cur; return 1 }
  read -k 1 new
  vi-surround-pair $new
  BUFFER[CURSOR]=$reply[2]
  BUFFER[MARK+1]=$reply[1]
  CURSOR=MARK
}
# Takes a motion (or the visual selection), then the surrounding to add
function vi-add-surround {
  zle -f vichange
  local save_cut=$CUTBUFFER save_cur new
  local -a reply
  zle .vi-change || return
  save_cur=$CURSOR
  zle .vi-cmd-mode
  read -k 1 new
  vi-surround-pair $new
  CUTBUFFER=$reply[1]$CUTBUFFER$reply[2]
  if [[ CURSOR -eq 0 || $BUFFER[CURSOR] = $'\n' ]]; then
    zle .vi-put-before -n 1
  else
    zle .vi-put-after -n 1
  fi
  CUTBUFFER=$save_cut CURSOR=$save_cur
}
zle -N vi-delete-surround
zle -N vi-change-surround
zle -N vi-add-surround
bindkey -M visual 'S' vi-add-surround

# Binding cs/ds/ys directly doesn't work: d, c and y are commands on their own,
# so with KEYTIMEOUT=1 they fire before a hand-typed s arrives. Instead d/c/y
# read the next key themselves (no timeout) and hand it on unless it's s
typeset -A vi_surround=(vi-delete vi-delete-surround vi-change vi-change-surround vi-yank vi-add-surround)
function vi-operator-or-surround {
  local op=${WIDGET%-or-surround} key
  if (( ! REGION_ACTIVE )); then
    read -k 1 key
    if [[ $key == s ]]; then
      zle $vi_surround[$op]
      return
    fi
    zle -U -- "$key"
  fi
  zle .$op
}
for op in vi-delete vi-change vi-yank; do
  zle -N $op-or-surround vi-operator-or-surround
done
bindkey -M vicmd d vi-delete-or-surround c vi-change-or-surround y vi-yank-or-surround
