GIT_CONFIG_DIR := $(HOME)/.config/git
DOTFILES_GIT_DIR := $(PWD)/git
NVIM_CONFIG_DIR := $(HOME)/.config/nvim

.PHONY: git git-install git-local git-check wezterm-config-install docker-config-install nvim-config-install brew-install brew-dump

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

brew-install:
	@echo "→ Installing packages from Brewfile"
	brew bundle --file=$(PWD)/Brewfile
	@echo "✓ Homebrew packages installed"

brew-dump:
	@echo "→ Dumping installed packages to Brewfile"
	brew bundle dump --file=$(PWD)/Brewfile --force
	@echo "✓ Brewfile updated"
