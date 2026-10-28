# Custom aliases

# Git
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull'

# Neovim
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# Claude
alias cc='claude --dangerously-skip-permissions --permission-mode acceptEdits'

# Shell
alias reload='source ~/.zshrc'

# The same aliases typed in the Russian layout: cc is сс, gpl is пзд.
# A map, not string indexing: indexing is by bytes when the locale is C.
() {
  local -A ru=(q й w ц e у r к t е y н u г i ш o щ p з a ф s ы d в f а g п
    h р j о k л l д z я x ч c с v м b и n т m ь)
  local name ru_name char
  for name in ${(k)aliases}; do
    [[ $name == *[^a-z]* ]] && continue
    ru_name=
    for char in ${(s::)name}; do ru_name+=$ru[$char]; done
    alias $ru_name=$aliases[$name]
  done
}
