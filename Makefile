GIT_CONFIG_DIR := $(HOME)/.config/git
DOTFILES_GIT_DIR := $(PWD)/git
STARSHIP_CONFIG_DIR := $(HOME)/.config
NVIM_CONFIG_DIR := $(HOME)/.config/nvim
GH_CONFIG_DIR := $(HOME)/.config/gh
CLAUDE_SKILLS_DIR := $(HOME)/.claude/skills
CLAUDE_HOOKS_DIR := $(HOME)/.claude/hooks
CLAUDE_SETTINGS := $(HOME)/.claude/settings.json

.PHONY: git git-install git-local git-check wezterm-config-install docker-config-install nvim-config-install gh-config-install starship-config-install zsh-install brew-install brew-dump claude-skills-install claude-hooks-install ssh-remote-vendor ssh-remote-install ssh-remote-test ssh-remote-clean-host

git-install: git-local git
	@echo "⚠ Don't forget to edit $(DOTFILES_GIT_DIR)/gitconfig-work with your work email"

git:
	@echo "→ Installing git config"
	mkdir -p $(GIT_CONFIG_DIR)
	ln -sf $(DOTFILES_GIT_DIR)/gitconfig $(GIT_CONFIG_DIR)/config
	ln -sf $(DOTFILES_GIT_DIR)/gitconfig-personal $(GIT_CONFIG_DIR)/gitconfig-personal
	ln -sf $(DOTFILES_GIT_DIR)/gitconfig-work $(GIT_CONFIG_DIR)/gitconfig-work
	ln -sf $(DOTFILES_GIT_DIR)/gitconfig-local $(GIT_CONFIG_DIR)/gitconfig-local
	@echo "✓ git config installed"

git-local:
	@if [ ! -f $(DOTFILES_GIT_DIR)/gitconfig-work ]; then \
		echo "→ Creating gitconfig-work from example"; \
		cp $(DOTFILES_GIT_DIR)/gitconfig-work.example $(DOTFILES_GIT_DIR)/gitconfig-work; \
		echo "⚠ Edit $(DOTFILES_GIT_DIR)/gitconfig-work with your work email"; \
	else \
		echo "✓ gitconfig-work already exists"; \
	fi
	@if [ ! -f $(DOTFILES_GIT_DIR)/gitconfig-local ]; then \
		echo "→ Creating gitconfig-local from example"; \
		cp $(DOTFILES_GIT_DIR)/gitconfig-local.example $(DOTFILES_GIT_DIR)/gitconfig-local; \
		echo "✓ gitconfig-local created"; \
	else \
		echo "✓ gitconfig-local already exists"; \
	fi

git-check:
	@echo "→ Git user.name:"
	@git config user.name
	@echo "→ Git user.email:"
	@git config user.email
	@echo "→ Config sources:"
	@git config --list --show-origin | grep user.

wezterm-config-install:
	@echo "→ Installing wezterm config"
	ln -sf $(PWD)/wezterm.lua $(HOME)/.wezterm.lua
	@echo "✓ wezterm config installed"

docker-config-install:
	@echo "→ Installing docker config"
	mkdir -p $(HOME)/.docker
	cp $(PWD)/docker/config.json $(HOME)/.docker/config.json
	@echo "✓ docker config installed"

nvim-config-install:
	@echo "→ Installing nvim config"
	mkdir -p $(HOME)/.config
	ln -sf $(PWD)/nvim $(NVIM_CONFIG_DIR)
	@echo "✓ nvim config installed"

gh-config-install:
	@echo "→ Installing gh config"
	mkdir -p $(GH_CONFIG_DIR)
	ln -sf $(PWD)/gh/config.yml $(GH_CONFIG_DIR)/config.yml
	@echo "✓ gh config installed"

starship-config-install:
	@echo "→ Installing starship config"
	mkdir -p $(STARSHIP_CONFIG_DIR)
	ln -sf $(PWD)/starship/starship.toml $(STARSHIP_CONFIG_DIR)/starship.toml
	@echo "✓ starship config installed"

zsh-install:
	@echo "→ Installing zsh config"
	ln -sf $(PWD)/zsh/zshrc $(HOME)/.zshrc
	@echo "✓ zsh config installed"

brew-install:
	@echo "→ Installing packages from Brewfile"
	brew bundle --file=$(PWD)/Brewfile
	@echo "✓ Homebrew packages installed"

brew-dump:
	@echo "→ Dumping installed packages to Brewfile"
	brew bundle dump --file=$(PWD)/Brewfile --force
	@echo "✓ Brewfile updated"

claude-skills-install:
	@echo "→ Installing Claude Code skills"
	mkdir -p $(CLAUDE_SKILLS_DIR)
	@for skill in $(PWD)/claude/skills/*/; do \
		skill_name=$$(basename "$$skill"); \
		ln -sfn "$$skill" "$(CLAUDE_SKILLS_DIR)/$$skill_name"; \
		echo "  ✓ $$skill_name"; \
	done
	@echo "✓ Claude Code skills installed"

claude-hooks-install:
	@echo "→ Installing Claude Code hooks"
	mkdir -p $(CLAUDE_HOOKS_DIR)
	@for hook in $(PWD)/claude/hooks/*.sh; do \
		[ -f "$$hook" ] || continue; \
		hook_name=$$(basename "$$hook"); \
		ln -sf "$$hook" "$(CLAUDE_HOOKS_DIR)/$$hook_name"; \
		echo "  ✓ $$hook_name"; \
	done
	@test -f $(CLAUDE_SETTINGS) || echo '{}' > $(CLAUDE_SETTINGS)
	@jq --slurpfile hooks $(PWD)/claude/hooks-config.json '.hooks = $$hooks[0]' $(CLAUDE_SETTINGS) > $(CLAUDE_SETTINGS).tmp && \
		mv $(CLAUDE_SETTINGS).tmp $(CLAUDE_SETTINGS)
	@echo "✓ Claude Code hooks installed"

ssh-remote-vendor:
	@echo "→ Vendoring remote nvim plugins from ssh-remote/plugins.txt"
	@dest="$(PWD)/ssh-remote/bundle/xdg/config/nvim/pack/plugins/start"; \
	mkdir -p "$$dest"; \
	grep -vE '^[[:space:]]*(#|$$)' "$(PWD)/ssh-remote/plugins.txt" | while read -r name url sha; do \
		d="$$dest/$$name"; \
		if [ -d "$$d" ] && [ ! -d "$$d/.git" ]; then rm -rf "$$d"; fi; \
		if [ ! -d "$$d/.git" ]; then git clone --quiet "$$url" "$$d" || { echo "✗ $$name: clone failed"; exit 1; }; \
		else git -C "$$d" fetch --quiet --all || { echo "✗ $$name: fetch failed"; exit 1; }; fi; \
		git -C "$$d" checkout --quiet "$$sha" || { echo "✗ $$name: checkout $$sha failed"; exit 1; }; \
		head="$$(git -C "$$d" rev-parse HEAD)"; \
		case "$$head" in "$$sha"*) ;; *) echo "✗ $$name: HEAD $$head != pinned $$sha"; exit 1;; esac; \
		rm -rf "$$d/.git"; \
		echo "  ✓ $$name @ $$sha"; \
	done
	@echo "✓ Remote nvim plugins vendored"

ssh-remote-install: ssh-remote-vendor
	@echo "→ Installing ssh-remote (wrapper auto-sourced via zsh/*.zsh)"
	@chmod +x $(PWD)/ssh-remote/bundle/bootstrap.sh
	@git -C $(PWD) update-index --chmod=+x ssh-remote/bundle/bootstrap.sh 2>/dev/null || true
	@test -d $(PWD)/ssh-remote/bundle/xdg/config/nvim/pack/plugins/start/mini.nvim \
		|| { echo "✗ plugins not vendored — run 'make ssh-remote-vendor'"; exit 1; }
	@echo "✓ ssh-remote installed — run 'reload' (or open a new shell)"

ssh-remote-test:
	@echo "→ Running ssh-remote tests"
	@test -f $(PWD)/ssh-remote/tests/test-guard.zsh -a -f $(PWD)/ssh-remote/tests/test-profile-select.sh \
		|| { echo "✗ test files not created yet (Tasks 3 & 7)"; exit 1; }
	@zsh $(PWD)/ssh-remote/tests/test-guard.zsh
	@sh  $(PWD)/ssh-remote/tests/test-profile-select.sh
	@XDG_CONFIG_HOME="$(PWD)/ssh-remote/bundle/xdg/config" \
		XDG_DATA_HOME="$$(mktemp -d)" XDG_STATE_HOME="$$(mktemp -d)" \
		XDG_CACHE_HOME="$$(mktemp -d)" \
		nvim --headless +'lua assert(vim.g.mapleader==" "); assert((require("mini.statusline")) ~= nil); io.write("nvim-ok\n")' +q
	@echo "✓ ssh-remote tests passed"

ssh-remote-clean-host:
	@test -n "$(HOST)" || { echo "usage: make ssh-remote-clean-host HOST=<ssh-host>"; exit 1; }
	@echo "→ Removing ~/.dotfiles-remote on $(HOST)"
	@ssh "$(HOST)" 'rm -rf ~/.dotfiles-remote'
	@echo "✓ cleaned $(HOST)"
