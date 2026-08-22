# One ordered list, owned by bootstrap.sh, which is what actually dispatches.
CONFIG_UNITS := $(shell ./scripts/bootstrap.sh units)
CONFIG_TARGETS := $(addprefix config-,$(CONFIG_UNITS))

# A bare `make` must not provision the machine: bootstrap is the first target
# and would otherwise run on a stray keystroke.
.DEFAULT_GOAL := help

.PHONY: help bootstrap bootstrap-brew bootstrap-tools config-install update \
	cleanup doctor inventory test git-check $(CONFIG_TARGETS)

# Derived from the `##` comment on each target, so a new entry point documents
# itself or the Make interface test fails. The per-unit line rides along with
# config-install to keep it in place, and names the units bootstrap.sh dispatches.
help: ## this list
	@awk -v units='$(CONFIG_UNITS)' 'BEGIN { FS = ":.*## " } \
		/^[a-z][a-z-]*:.*## / { printf "make %-16s %s\n", $$1, $$2 } \
		/^config-install:/ { printf "make %-16s one unit, e.g. make config-nvim\n                      units: %s\n", "config-<unit>", units }' \
		$(MAKEFILE_LIST)
	@printf '\nFORCE=1   back up and replace a target that already exists\n'
	@printf 'DRY_RUN=1 print what would change and write nothing\n'
	@printf '\nA bare `make` prints this. See README.md for the detail.\n'

# Full provisioning of a new machine: Homebrew, user-space tools, configs, doctor.
bootstrap: ## provision a new machine (INSTALL_HOMEBREW=1 if brew is absent)
	@./scripts/bootstrap.sh all

bootstrap-brew: ## apply Brewfile and, when present, Brewfile.local
	@./scripts/bootstrap.sh brew

bootstrap-tools: ## install the pinned NVM and Node
	@./scripts/bootstrap.sh tools

# Install every configuration unit. Idempotent; safe to rerun.
config-install: ## install every configuration unit
	@./scripts/bootstrap.sh config

# Install a single unit, e.g. make config-nvim
$(CONFIG_TARGETS): config-%:
	@./scripts/bootstrap.sh config $*

# Refresh an existing machine: pull, brew update, reinstall manifests, upgrade,
# verify. The pull happens here rather than inside the script, so bash is not
# reading a file that changes underneath it.
update: ## refresh this machine, then verify it
	@git pull --ff-only || printf 'warning: could not fast-forward this checkout; continuing with what is here\n' >&2
	@./scripts/bootstrap.sh update

# Uninstall what no manifest declares. Homebrew lists it and asks; FORCE=1 skips
# the question. Never run as part of update.
cleanup: ## uninstall what no manifest declares (FORCE=1 skips the prompt)
	@./scripts/bootstrap.sh cleanup

# Report manifest entries that are missing on this machine.
doctor: ## what the manifests declare and this machine lacks
	@./scripts/doctor.sh

# Report software installed on this machine that no manifest declares.
inventory: ## what this machine has and no manifest declares
	@./scripts/inventory.sh compare

test: ## run the test suite
	@for test_file in tests/*_test.sh; do bash "$$test_file" || exit $$?; done

git-check: ## active user.name and user.email, and where they come from
	@printf '%s\n' 'Git user.name:'
	@git config user.name
	@printf '%s\n' 'Git user.email:'
	@git config user.email
	@printf '%s\n' 'Config sources:'
	@git config --list --show-origin | grep 'user\.'
