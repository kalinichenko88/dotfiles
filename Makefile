CONFIG_UNITS := dev-dirs git ssh zsh nvim wezterm gh starship docker claude
CONFIG_TARGETS := $(addprefix config-,$(CONFIG_UNITS))

# A bare `make` must not provision the machine: bootstrap is the first target
# and would otherwise run on a stray keystroke.
.DEFAULT_GOAL := help

.PHONY: help bootstrap bootstrap-brew bootstrap-tools config-install update \
	doctor inventory test git-check $(CONFIG_TARGETS) \
	ssh-remote-vendor ssh-remote-install ssh-remote-test ssh-remote-clean-host

help:
	@printf 'make bootstrap   provision a new machine (INSTALL_HOMEBREW=1 if brew is absent)\n'
	@printf 'make update      refresh this machine, then verify it\n'
	@printf 'make doctor      what the manifests declare and this machine lacks\n'
	@printf 'make inventory   what this machine has and no manifest declares\n'
	@printf 'make test        run the test suite\n'
	@printf '\nSee README.md for the rest.\n'

# Full provisioning of a new machine: Homebrew, user-space tools, configs, doctor.
bootstrap:
	@./scripts/bootstrap.sh all

bootstrap-brew:
	@./scripts/bootstrap.sh brew

bootstrap-tools:
	@./scripts/bootstrap.sh tools

# Install every configuration unit. Idempotent; safe to rerun.
config-install:
	@./scripts/bootstrap.sh config

# Install a single unit, e.g. make config-nvim
$(CONFIG_TARGETS): config-%:
	@./scripts/bootstrap.sh config $*

# Refresh an existing machine: brew update, reinstall manifests, upgrade, verify.
update:
	@./scripts/bootstrap.sh update

# Report manifest entries that are missing on this machine.
doctor:
	@./scripts/doctor.sh

# Report software installed on this machine that no manifest declares.
inventory:
	@./scripts/inventory.sh compare

test:
	@for test_file in tests/*_test.sh; do bash "$$test_file" || exit $$?; done

git-check:
	@printf '%s\n' 'Git user.name:'
	@git config user.name
	@printf '%s\n' 'Git user.email:'
	@git config user.email
	@printf '%s\n' 'Config sources:'
	@git config --list --show-origin | grep 'user\.'

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
	@test -f $(PWD)/ssh-remote/tests/test-guard.zsh -a -f $(PWD)/ssh-remote/tests/test-profile-select.sh -a -f $(PWD)/ssh-remote/tests/test-nvim-install.sh \
		|| { echo "✗ test files not created yet (Tasks 3, 7 & 11)"; exit 1; }
	@zsh $(PWD)/ssh-remote/tests/test-guard.zsh
	@sh  $(PWD)/ssh-remote/tests/test-profile-select.sh
	@sh  $(PWD)/ssh-remote/tests/test-nvim-install.sh
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
