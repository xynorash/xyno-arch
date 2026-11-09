# XYNORASH terminal environment for bash. Sourced from ~/.bashrc (interactive only).
#
#   prompt       oh-my-posh with xynorash.omp.json (3-line cockpit; vitals below)
#   completions  carapace (flags, subcommands and values for 1000+ CLI tools)
#   line editor  ble.sh: history predictions, syntax colours, menu completion,
#                transient prompt (settings in blerc)
#   navigation   zoxide (z, zi)
#   banner       fastfetch with the XYNORASH logo

_xyno_dir=${XDG_CONFIG_HOME:-$HOME/.config}/xynorash

# No glyphs, escapes or ble.sh where they cannot work: the Linux console (TERM=linux),
# dumb terminals (editor/IDE panes) and shells without a tty (`bash -i < file`).
# They keep the plain prompt from ~/.bashrc, plus the functions and aliases below.
_xyno_plain=; [[ $TERM == @(linux|dumb|'') || ! -t 0 || ! -t 1 ]] && _xyno_plain=1

# ── Banner: sized to the terminal, rendered in the background ────────────────
# Started first so its render (~110 ms) overlaps with ble.sh loading instead of
# adding to it; shown below, before ble.sh attaches.
#   >=180 cols  large logo + info      130-179  medium logo + info
#   45-129      compact info, no logo  <45      none

_xyno_banner_args() {   # $1 = columns -> _xyno_banner_tier, _xyno_banner_cmd
  if   (( $1 >= 180 )); then _xyno_banner_tier=L _xyno_banner_cmd=(--config config.jsonc)
  elif (( $1 >= 130 )); then _xyno_banner_tier=M _xyno_banner_cmd=(--config config.jsonc --logo-type file-raw --logo xynorash-m.txt --logo-width 54 --logo-height 17)
  elif (( $1 >= 45  )); then _xyno_banner_tier=S _xyno_banner_cmd=(--config config-compact.jsonc)
  else                       _xyno_banner_tier=  _xyno_banner_cmd=()
  fi
}

_xyno_banner_run() {    # fastfetch with the current _xyno_banner_cmd, from its own directory
  ( cd "$_xyno_dir/fastfetch" && exec fastfetch "${_xyno_banner_cmd[@]}" --pipe false 2>/dev/null )
}

_xyno_banner_start() {
  [[ -z $_xyno_plain && -z ${XYNO_NO_FETCH:-} ]] && command -v fastfetch >/dev/null || return 0
  local cols; read -r _ cols < <(stty size 2>/dev/null); cols=${cols:-80}
  _xyno_banner_args "$cols"
  [[ $_xyno_banner_tier ]] || return 0
  _xyno_banner_tier0=$_xyno_banner_tier
  exec {_xyno_banner_fd}< <(_xyno_banner_run)   # a pipe, not a temp file: nothing to leak or race
}

# A tiling window manager often resizes a new terminal right after it opens, so
# the size is checked again here; if the tier changed, render again.
_xyno_banner_show() {
  [[ -n ${_xyno_banner_fd-} ]] || return 0
  local cols; read -r _ cols < <(stty size 2>/dev/null); cols=${cols:-80}
  _xyno_banner_args "$cols"
  if [[ $_xyno_banner_tier == "$_xyno_banner_tier0" ]]; then
    cat <&"$_xyno_banner_fd"          # blocks until the render has finished
  elif [[ $_xyno_banner_tier ]]; then
    _xyno_banner_run
  fi
  exec {_xyno_banner_fd}<&-
  unset _xyno_banner_fd _xyno_banner_tier _xyno_banner_tier0 _xyno_banner_cmd
}

_xyno_banner_start

# ble.sh must load before the prompt engine (it enables the transient prompt)
# and attach at the very end of ~/.bashrc: `[[ ${BLE_VERSION-} ]] && ble-attach`.
[[ -z $_xyno_plain && -r /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --noattach --rcfile "$_xyno_dir/blerc"

# ── History ──────────────────────────────────────────────────────────────────
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cmdhist

# ── Live vitals, read by the prompt as XYNO_* env vars ───────────────────────
# Pure bash on /proc: no process is forked per prompt, except `df` every 5th
# and `ip` every 20th.

_xyno_n=0 _xyno_cpu_total=0 _xyno_cpu_idle=0
[[ $EUID -eq 0 ]] && export XYNO_IS_ADMIN=1

_xyno_vitals() {
  local _ u n s i w irq sirq st total idle dt di up p
  (( _xyno_n++ ))

  # CPU: share of non-idle time since the previous prompt
  read -r _ u n s i w irq sirq st _ < /proc/stat
  total=$(( u + n + s + i + w + irq + sirq + st )) idle=$(( i + w ))
  dt=$(( total - _xyno_cpu_total )) di=$(( idle - _xyno_cpu_idle ))
  (( dt > 0 )) && export XYNO_CPU=$(( 100 * (dt - di) / dt ))
  _xyno_cpu_total=$total _xyno_cpu_idle=$idle

  # Uptime
  read -r up _ < /proc/uptime; up=${up%.*}
  if   (( up >= 86400 )); then XYNO_UPTIME="$(( up / 86400 ))d $(( up % 86400 / 3600 ))h"
  elif (( up >= 3600  )); then XYNO_UPTIME="$(( up / 3600 ))h $(( up % 3600 / 60 ))m"
  else                         XYNO_UPTIME="$(( up / 60 ))m"
  fi
  export XYNO_UPTIME

  # Process count: numeric entries under /proc
  p=(/proc/[0-9]*); export XYNO_PROCS=${#p[@]}

  # Disk usage of / (refreshed every 5 prompts)
  if (( _xyno_n % 5 == 1 )); then
    p=$(df --output=pcent / 2>/dev/null); p=${p##* }; export XYNO_DISK=${p%\%}
  fi

  # Primary IPv4, from the default route so docker/tailscale are skipped (every 20 prompts)
  if (( _xyno_n % 20 == 1 )); then
    p=($(ip -4 route get 1.1.1.1 2>/dev/null))
    for (( i = 0; i < ${#p[@]}; i++ )); do
      [[ ${p[i]} == src ]] && { export XYNO_IP=${p[i+1]}; break; }
    done
  fi
}

# ── Prompt ───────────────────────────────────────────────────────────────────

if [[ -z $_xyno_plain ]] && command -v oh-my-posh >/dev/null && [[ -f $_xyno_dir/xynorash.omp.json ]]; then
  # --print: the cached init script is not keyed on ble.sh, so it can miss the transient-prompt hooks
  eval "$(oh-my-posh init bash --config "$_xyno_dir/xynorash.omp.json" --print)"
  # After oh-my-posh's hook: it reads the previous exit status first, and the
  # prompt string is only rendered once every hook has run.
  [[ ${PROMPT_COMMAND[*]-} == *_xyno_vitals* ]] || PROMPT_COMMAND+=(_xyno_vitals)   # once, also when re-sourced
fi

# ── Completions, navigation ──────────────────────────────────────────────────

if command -v carapace >/dev/null; then
  # bash-ble format (descriptions in the ble.sh menu) with a wrapped completer.
  # The plain `bash` format breaks under ble.sh: its `read` wrapper chokes on the
  # IFS=$'\001' read in carapace's completer.
  #   - menu only: the ghost-text pass spawns nothing (history + ble.sh's own
  #     sources), which cut typing CPU by ~55 percent; file names stay only where
  #     the word contains a /
  #   - desc style only when carapace sent descriptions, so plain lists (sudo
  #     <command>, paths) stay multi-column
  #   - carapace's ERR/_ placeholder entries (git outside a repo, no match) are dropped
  # No CARAPACE_BRIDGES: zsh/fish are not installed and the bash bridge adds only empty lists.
  _xyno_carapace() {
    [[ ${BLE_ATTACHED-} ]] || { _carapace_completer; return; }
    if [[ :$comp_type: == *:auto:* ]]; then
      [[ ${COMP_WORDS[COMP_CWORD]} == */* ]] || compopt -o ble/no-default
      return
    fi
    compopt -o ble/no-default
    local IFS=$'\n' c cand desc=
    mapfile -t c < <(printf '%s\n' "${COMP_LINE:0:COMP_POINT}" | sed -e "s/ \$/ ''/" -e 's/"/\"/g' |
                     xargs carapace "${COMP_WORDS[0]}" bash-ble 2>/dev/null | grep -Pav $'\t(ERR[0-9]*|_)\x1c')
    for cand in "${c[@]}"; do
      [[ $cand ]] || continue
      [[ ${cand##*$'\x1c'} ]] && desc=1
      ble/complete/cand/yield mandb "${cand%$'\t'*}" "${cand##*$'\t'}"
    done
    [[ $desc ]] && bleopt complete_menu_style=desc
  }
  source <(carapace _carapace bash-ble | sed 's/-F _carapace_completer_ble/-F _xyno_carapace/')
fi
command -v zoxide >/dev/null && [[ ${PROMPT_COMMAND[*]-} != *__zoxide_hook* ]] && eval "$(zoxide init bash --cmd z)"

# ── Readline (without ble.sh; with it, keys live in blerc) ─────────────────

if [[ -z ${BLE_VERSION-} ]]; then
  bind 'set show-all-if-ambiguous on'
  bind 'set completion-ignore-case on'
  bind 'TAB: menu-complete'
  bind '"\e[Z": menu-complete-backward'
  bind '"\e[A": history-search-backward'      # Up/Down: history entries starting
  bind '"\e[B": history-search-forward'       # with what is already typed
  bind '"\e[1;5D": backward-word'             # Ctrl+Left / Ctrl+Right
  bind '"\e[1;5C": forward-word'
  bind '"\e[1;3D": backward-word'             # Alt+Left / Alt+Right
  bind '"\e[1;3C": forward-word'
  bind '"\C-w": backward-kill-word'
  bind '"\ed": kill-word'
fi

# ── Functions ────────────────────────────────────────────────────────────────

mkcd()  { mkdir -p -- "$1" && cd -- "$1"; }
ff()    { fd --type f "$@"; }
k9()    { pkill -9 -x -- "$1"; }
trash() { gio trash -- "$@"; }
docs()  { cd -- "$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documents")"; }
alias la='ls -lh --color=auto'
alias ll='ls -lAh --color=auto'

# Git shortcuts
alias gs='git status'
alias ga='git add .'
alias gp='git push'
alias gpush='git push'
alias gpull='git pull'
alias gcl='git clone'
g()     { z github; }
gcom()  { git add . && git commit -m "$*"; }
lazyg() { git add . && git commit -m "$*" && git push; }

# Pull the latest xyno-arch (home configs are symlinks into the repo)
xyno-update() { git -C "${XYNO_ARCH:-$HOME/xyno-arch}" pull --ff-only && echo "updated; open a new terminal"; }

xyno-help() {
  local t=$'\e[95m' s=$'\e[94m' c=$'\e[92m' d=$'\e[97m' a=$'\e[93m' r=$'\e[0m'
  cat <<EOF
${t}󰘳 XYNORASH shell${r}

${s}󰊢 Git${r}
  ${c}gs${r} ${a}→${r} ${d}status${r}     ${c}ga${r} ${a}→${r} ${d}add .${r}     ${c}gp / gpush${r} ${a}→${r} ${d}push${r}     ${c}gpull${r} ${a}→${r} ${d}pull${r}
  ${c}gcl <repo>${r} ${a}→${r} ${d}clone${r}     ${c}gcom <msg>${r} ${a}→${r} ${d}add + commit${r}     ${c}lazyg <msg>${r} ${a}→${r} ${d}add + commit + push${r}
  ${c}g${r} ${a}→${r} ${d}jump to ~/github (zoxide)${r}

${s}󰘴 Shell${r}
  ${c}z <dir>${r} / ${c}zi${r} ${a}→${r} ${d}smart cd (zoxide)${r}     ${c}mkcd <dir>${r} ${a}→${r} ${d}create + enter${r}     ${c}ff <name>${r} ${a}→${r} ${d}find files (fd)${r}
  ${c}ll${r} / ${c}la${r} ${a}→${r} ${d}list files${r}     ${c}docs${r} ${a}→${r} ${d}Documents${r}     ${c}trash <path>${r} ${a}→${r} ${d}move to trash${r}     ${c}k9 <name>${r} ${a}→${r} ${d}kill -9 by name${r}
  ${c}xyno-update${r} ${a}→${r} ${d}git pull xyno-arch${r}

${s}󰌌 Keys${r}
  ${c}Up/Down${r} ${a}→${r} ${d}history starting with typed text${r}     ${c}Ctrl+R${r} ${a}→${r} ${d}fuzzy history list (fzf)${r}     ${c}Ctrl+T${r} ${a}→${r} ${d}pick files${r}     ${c}Alt+C${r} ${a}→${r} ${d}cd picker${r}
  ${c}Right/End${r} ${a}→${r} ${d}accept grey suggestion${r}     ${c}Ctrl+Right${r} ${a}→${r} ${d}accept one word of it${r}     ${c}Alt+.${r} ${a}→${r} ${d}last argument${r}
  ${c}Tab/Shift+Tab${r} ${a}→${r} ${d}cycle completions (arrows move in the list, Ctrl+G cancels)${r}
  ${c}Shift+Enter${r} ${a}→${r} ${d}new line (Enter runs when complete)${r}     ${c}Ctrl+Z/Ctrl+Y${r} ${a}→${r} ${d}undo/redo${r}     ${c}Ctrl+L${r} ${a}→${r} ${d}clear${r}
  ${c}Ctrl+Left/Right${r} ${a}→${r} ${d}word jump${r}     ${c}Ctrl+W, Ctrl+Backspace, Alt+Backspace${r} ${a}→${r} ${d}delete word${r}
EOF
}

_xyno_banner_show
unset -f _xyno_banner_args _xyno_banner_run _xyno_banner_start _xyno_banner_show
unset _xyno_dir _xyno_plain
