export PASSWORD_STORE_DIR="$HOME/.local/share/password-store"
export EDITOR=nvim
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export BROWSER=surf
typeset -U path PATH
path+=(/usr/local/texlive/*/bin/amd64-freebsd(N[-1]))

# Token for the Claude Code GitHub plugin (MCP server), taken from the gh login
if [[ -z $GITHUB_PERSONAL_ACCESS_TOKEN ]] && (( $+commands[gh] )); then
  export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"
fi
