# Shell behaviour, formerly inherited from Oh My Zsh. Only its defaults were
# ever used here: the theme was dead because starship loads later and owns the
# prompt, and the git plugin silently overrode aliases declared in aliases.zsh.

export EDITOR='nvim'

# Emacs keybindings. Zsh would otherwise infer vi mode from $EDITOR.
bindkey -e

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history hist_expire_dups_first hist_ignore_dups \
  hist_ignore_space hist_verify share_history

# Navigation, editing, and job control
setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus \
  always_to_end complete_in_word interactive_comments long_list_jobs prompt_subst
unsetopt flow_control

# Completion. Homebrew's function directory is added here rather than relying
# on this file loading after path.zsh.
[[ -d /opt/homebrew/share/zsh/site-functions ]] &&
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}'
zstyle ':completion:*' use-cache on
