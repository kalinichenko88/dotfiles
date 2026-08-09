CONFIG_UNITS := dev-dirs git ssh zsh nvim wezterm gh starship docker claude
CONFIG_TARGETS := $(addprefix config-,$(CONFIG_UNITS))

# A bare `make` must not provision the machine: bootstrap is the first target
# and would otherwise run on a stray keystroke.
.DEFAULT_GOAL := help

.PHONY: help bootstrap bootstrap-brew bootstrap-tools config-install update \
	doctor inventory test git-check $(CONFIG_TARGETS)

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
