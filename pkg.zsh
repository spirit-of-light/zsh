# pkg helpers: fuzzy search/install/remove with fzf, sourced from .zshrc

# fuzzy pkg search: browse the whole repo, preview details, install selection
pkgf() {
  local sel
  sel=$(pkg rquery '%n\t%c' \
    | awk -F'\t' '
        { n[NR]=$1; c[NR]=$2; if (length($1)>nw) nw=length($1) }
        END {
          if (nw>40) nw=40
          for (i=1;i<=NR;i++)
            printf "%s\t\033[1;36m%-*.*s\033[0m  \033[2m%s\033[0m\n",
                   n[i], nw, nw, n[i], c[i]
        }' \
    | fzf --multi --ansi --delimiter='\t' --with-nth=2 \
          --bind 'change:first' \
          --preview 'pkg rquery "%n-%v\n%c\n%w\n\n%e" {1}' \
          --preview-window=right:50%:wrap \
    | cut -f1)
  [[ -n $sel ]] && sudo pkg install ${(f)sel}
}

# print what removing the given packages would do: the packages themselves, installed
# packages that depend on them (pkg delete removes those too), and the orphans that
# a following `pkg autoremove` would then remove
_pkgf_plan() {
  { pkg query '%n\t%a'; echo '---'; pkg query '%n\t%dn'; echo '---'
    pkg query '%n\t%b'; echo '---'; pkg query '%n\t%B'; echo '---'; printf '%s\n' "$@" } \
    | awk -F'\t' '
        BEGIN { sec = 1 }
        $0 == "---" { sec++; next }
        sec == 1 { auto[$1] = $2; names[++np] = $1; next }
        sec == 2 { if ($2 != "") { ef[++ne] = $1; et[ne] = $2 }; next }
        sec == 3 { prov[$2] = prov[$2] " " $1; next }
        sec == 4 { if ($2 != "") { rq[++nr] = $1; rl[nr] = $2 }; next }
        sec == 5 { sel[$1] = 1; gone[$1] = 1; next }
        END {
          # installed packages that depend (directly or not) on the selection
          do { ch = 0
            for (i = 1; i <= ne; i++)
              if ((et[i] in gone) && !(ef[i] in gone)) { gone[ef[i]] = 1; dep[ef[i]] = 1; ch = 1 }
          } while (ch)
          # shared-library dependencies also keep a package in use
          for (i = 1; i <= nr; i++) {
            m = split(prov[rl[i]], pv, " ")
            for (j = 1; j <= m; j++) if (pv[j] != rq[i]) { sf[++ns] = rq[i]; st[ns] = pv[j] }
          }
          # automatic packages nothing remaining needs, repeated until stable
          do { ch = 0
            delete rem
            for (i = 1; i <= ne; i++) if (!(ef[i] in gone)) rem[et[i]]++
            for (i = 1; i <= ns; i++) if (!(sf[i] in gone)) rem[st[i]]++
            for (i = 1; i <= np; i++) {
              p = names[i]
              if (!(p in gone) && auto[p] == 1 && rem[p] == 0) { gone[p] = 1; orph[p] = 1; ch = 1 }
            }
          } while (ch)
          for (i = 1; i <= np; i++) { p = names[i]
            if (p in sel) s = s "  " p "\n"
            else if (p in dep) d = d "  " p "\n"
            else if (p in orph) o = o "  " p "\n"
          }
          printf "\033[1;31mRemoved (selected):\033[0m\n%s", s
          if (d != "") printf "\n\033[1;33mRemoved (depend on selected):\033[0m\n%s", d
          if (o != "") printf "\n\033[1;35mAutoremoved (no longer needed):\033[0m\n%s", o
        }'
}

# show the plan from _pkgf_plan in a bordered pop-up (y/Enter = proceed, n/q/Esc = cancel),
# then pkg delete + pkg autoremove
_pkgf_remove() {
  _pkgf_plan "$@" \
    | fzf --ansi --no-input --no-sort --layout=reverse --height='~80%' \
          --border=rounded --border-label=' Remove packages ' \
          --header='y/Enter: proceed   n/q/Esc: cancel   j/k ^d/^u g/G: scroll' --header-first \
          --info=hidden --pointer=' ' --color='pointer:-1,bg+:-1' \
          --bind='y:accept,enter:accept,n:abort,q:abort' \
          --bind='j:down,k:up,ctrl-d:half-page-down,ctrl-u:half-page-up,g:first,G:last' \
          > /dev/null || return 1
  sudo pkg delete -y "$@" && sudo pkg autoremove -y
}

# fuzzy search installed packages, preview details, remove selection (plan, confirm, autoremove)
pkgfi() {
  local sel
  sel=$(pkg query '%n\t%c' \
    | awk -F'\t' '
        { n[NR]=$1; c[NR]=$2; if (length($1)>nw) nw=length($1) }
        END {
          if (nw>40) nw=40
          for (i=1;i<=NR;i++)
            printf "%s\t\033[1;36m%-*.*s\033[0m  \033[2m%s\033[0m\n",
                   n[i], nw, nw, n[i], c[i]
        }' \
    | fzf --multi --ansi --delimiter='\t' --with-nth=2 \
          --bind 'change:first' \
          --preview 'pkg query "%n-%v\n%c\n%w\n\n%e" {1}' \
          --preview-window=right:50%:wrap \
    | cut -f1)
  [[ -n $sel ]] && _pkgf_remove ${(f)sel}
}

# like pkgfi, but only manually installed packages (pkg prime-list)
pkgfip() {
  local sel
  sel=$(pkg prime-list | xargs pkg query '%n\t%c' \
    | awk -F'\t' '
        { n[NR]=$1; c[NR]=$2; if (length($1)>nw) nw=length($1) }
        END {
          if (nw>40) nw=40
          for (i=1;i<=NR;i++)
            printf "%s\t\033[1;36m%-*.*s\033[0m  \033[2m%s\033[0m\n",
                   n[i], nw, nw, n[i], c[i]
        }' \
    | fzf --multi --ansi --delimiter='\t' --with-nth=2 \
          --bind 'change:first' \
          --preview 'pkg query "%n-%v\n%c\n%w\n\n%e" {1}' \
          --preview-window=right:50%:wrap \
    | cut -f1)
  [[ -n $sel ]] && _pkgf_remove ${(f)sel}
}
