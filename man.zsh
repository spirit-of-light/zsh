# man page helpers: fuzzy find a page with fzf, sourced from .zshrc

# fuzzy man page search: browse every page under manpath, preview it rendered,
# open the selection in man; an argument becomes the initial query (manf ls)
manf() {
  local sel d
  # turn mandoc's overstrike (x^Hx bold, _^Hx underline) into the same colours
  # LESS_TERMCAP gives man in less: bold cyan, underlined green
  local overstrike='s/((?:(.)\x08\2)+)/"\e[1;36m".($1=~s|.\x08||gr)."\e[0m"/ge;
                    s/((?:_\x08.)+)/"\e[4;32m".($1=~s|_\x08||gr)."\e[0m"/ge'
  sel=$(for d in ${(s.:.)$(manpath)}; do print -l $d/man*/*(N-.); done \
    | awk '
        { f = $0; sub(/.*\//, "", f); sub(/\.(gz|bz2|xz)$/, "", f)
          n = f; sub(/\.[^.]*$/, "", n); s = substr(f, length(n) + 2)
          printf "%s\t\033[1;36m%s\033[0m\033[2m(%s)\033[0m\n", $0, n, s }' \
    | sort -t$'\t' -k2,2 -u \
    | fzf --ansi --delimiter='\t' --with-nth=2 --query="$*" \
          --bind 'change:first' \
          --preview "mandoc -O width=\$FZF_PREVIEW_COLUMNS {1} 2>/dev/null | perl -pe ${(q)overstrike}" \
          --preview-window=right:60% \
    | cut -f1)
  [[ -n $sel ]] && man -l $sel
}
