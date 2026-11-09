#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias d='docker'
alias lzd='lazydocker'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"
export ANDROID_HOME="$HOME/sdk/android-sdk"
export CARGO_HOME="$HOME/sdk/cargo"
export RUSTUP_HOME="$HOME/sdk/rustup"
export GRADLE_USER_HOME="$HOME/sdk/gradle"
export GOPATH="$HOME/sdk/go"
export SDKMAN_DIR="$HOME/sdk/sdkman"
export NVM_DIR="$HOME/sdk/nvm"
export PYENV_ROOT="$HOME/sdk/pyenv"
export BUN_INSTALL="$HOME/sdk/bun"
export DENO_INSTALL="$HOME/sdk/deno"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
[[ -r $HOME/sdk/cargo/env ]] && . "$HOME/sdk/cargo/env"

# XYNORASH prompt, completions, vitals and the fastfetch banner
[[ -r ~/.config/xynorash/shell.sh ]] && . ~/.config/xynorash/shell.sh
[[ ${BLE_VERSION-} ]] && ble-attach
export PATH="$HOME/sdk/flutter-sdk/bin:$PATH"
export PUB_CACHE="$HOME/sdk/pub-cache"
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable
