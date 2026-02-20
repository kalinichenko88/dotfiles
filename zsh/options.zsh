# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="fwalch"
export DEFAULT_USER="$USER"
zstyle ':omz:update' mode reminder
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Editor
export EDITOR='nvim'
