# dotfiles

Reproducible macOS workstation configuration for an Apple Silicon Mac. The
reviewed target is an M1 Pro using Homebrew at `/opt/homebrew`.

The repository has three responsibilities:

1. install the shared workstation baseline on a new machine;
2. keep an existing machine up to date and report drift in both directions;
3. stay publishable — no secrets, no personal inventory, no agent planning notes.

No command here ever uninstalls software.

## What Is Managed

- Homebrew taps, formulae, casks, terminal applications, and fonts in
  `Brewfile`;
- exact Node `v24.18.0` and UV tool versions under `setup/`;
- `~/Dev/Personal` and `~/Dev/Work`, which drive the Git identity switch;
- Git, Zsh, Neovim, WezTerm, GitHub CLI, Starship, Docker CLI, and Claude Code
  public configuration;
- explicit checks for standalone or application-bundled AI CLIs;
- a manual checklist for applications without a Homebrew cask.

WezTerm Nightly and agterm are the retained terminal baseline. Ghostty, kitty,
and Alacritty are not part of the target. The retained fonts are JetBrains Mono
and JetBrains Mono Nerd Font.

Homebrew Bun is authoritative. Tracked Zsh configuration does not load a
standalone `~/.bun` installation. Poppler remains for Codex and Claude PDF
workflows, and SoX remains for Claude voice workflows.

OpenClaw, Pi, Perplexity, ZCode, and Buzz are excluded from the baseline.

## Target Bootstrap

Prerequisites:

- Apple Silicon macOS;
- internet access;
- Xcode Command Line Tools (`xcode-select --install` when absent);
- repository access through the configured SSH key.

Clone the repository:

```bash
git clone git@github.com:kalinichenko88/dotfiles.git ~/Dev/Personal/dotfiles
cd ~/Dev/Personal/dotfiles
```

Preview a fresh target, including the explicitly authorized Homebrew installer:

```bash
DRY_RUN=1 INSTALL_HOMEBREW=1 make bootstrap
```

Apply the complete baseline:

```bash
INSTALL_HOMEBREW=1 make bootstrap
```

The full flow checks the platform, applies `Brewfile`, installs pinned user-space
tools, installs configuration, runs strict doctor verification, and only then
creates `~/.config/dotfiles/bootstrap-complete`.

Homebrew installation is never inferred from a generic bootstrap request. When
Homebrew is absent, `INSTALL_HOMEBREW=1` is required. On a machine where Brew is
already installed, the flag may be omitted.

## Safety Flags

- `DRY_RUN=1` prints mutation commands without executing them.
- Existing configuration is never replaced by default.
- `FORCE=1` moves each conflicting target to a timestamped sibling such as
  `.zshrc.backup.20260806-120000` before installing the reviewed config.

Use force only after inspecting the reported conflict:

```bash
FORCE=1 make config-install
```

Git work/local identity files are created from examples only when absent and are
then preserved. Claude settings are merged through `jq`; non-hook keys are
preserved, and a changed existing file requires `FORCE=1`. Docker config is
copied rather than linked because Docker may rewrite it.

## Public Commands

| Command | Purpose |
| --- | --- |
| `make bootstrap` | Run Brew, tools, config, strict doctor, and target marker |
| `make bootstrap-brew` | Apply `Brewfile` and, when present, `Brewfile.local` |
| `make bootstrap-tools` | Install pinned Oh My Zsh, NVM/Node, and UV tools |
| `make config-install` | Install every configuration unit safely |
| `make config-<unit>` | Install one unit, e.g. `make config-nvim` |
| `make update` | `brew update`, reapply manifests, `brew upgrade`, then doctor |
| `make doctor` | Report manifest entries missing on this machine |
| `make inventory` | Report software installed here that no manifest declares |
| `make test` | Run shell integration and regression tests |

Units are `dev-dirs`, `git`, `zsh`, `nvim`, `wezterm`, `gh`, `starship`,
`docker`, and `claude`. Every target is idempotent and safe to rerun.

`brew-dump` is intentionally absent: a raw dump must never overwrite the curated
Brewfile.

## Keeping a Machine Current

```bash
make update
```

This refreshes Homebrew, reinstalls anything the manifests gained since the last
run, upgrades installed packages, and finishes with a doctor pass. Nothing is
removed.

Drift is reported from both directions. `make doctor` lists manifest entries
that are missing here; `make inventory` lists taps, formulae, casks, Node
versions, and UV tools installed here that no manifest declares. Inventory
writes its Homebrew dump to a temporary directory that is removed on exit and
never modifies `Brewfile`.

For cask-backed applications, doctor accepts either a Homebrew receipt or the
expected application bundle, so a manually installed app is not reinstalled just
to change package-manager ownership.

## Machine-Specific Software

This repository is public, so software that belongs to one machine is never
tracked. Declare it in the gitignored siblings instead; bootstrap, update, and
doctor read them automatically when present:

| File | Holds |
| --- | --- |
| `Brewfile.local` | extra `tap`/`brew`/`cask` lines for this machine |
| `setup/cask-apps.local.tsv` | `cask-token<TAB>/Applications/Name.app` |
| `setup/manual-checks.local.tsv` | `app<TAB>Display Name<TAB>/Applications/Name.app` |

The tracked manifests must stay free of personal inventory; `make test` fails if
machine-specific casks or an application list reappear in them.

## Doctor

```bash
make doctor
```

Required failures include missing taps/packages, exact Node or UV tools, and
tracked configuration. Outdated packages, unsupported manual applications, and
authentication state are warnings. Auth command output is suppressed, and each
external probe has a timeout.

After a successful target bootstrap, doctor additionally runs
`brew bundle check --no-upgrade` for `Brewfile` and, when present,
`Brewfile.local`.

Available upgrades are reported separately and do not make an otherwise present
dependency look missing.

## Manual Applications and Authentication

This repository intentionally does not use `mas` or copy application databases.
`setup/manual-checks.tsv` is the authoritative list of hand-installed tools and
their verification probes; [`setup/manual-apps.md`](setup/manual-apps.md) holds
the login commands that create the sessions those probes look for.

Authentication files, tokens, histories, caches, model data, browser profiles,
SSH keys, and Docker credentials must never be added to this repository.

## Configuration Destinations

| Source | Target |
| --- | --- |
| `git/gitconfig` | `~/.config/git/config` |
| `git/gitconfig-personal` | `~/.config/git/gitconfig-personal` |
| `zsh/zshrc` | `~/.zshrc` |
| `nvim/` | `~/.config/nvim` |
| `wezterm.lua` | `~/.wezterm.lua` |
| `gh/config.yml` | `~/.config/gh/config.yml` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `docker/config.json` | `~/.docker/config.json` (safe copy) |
| `claude/skills/*` | `~/.claude/skills/*` |
| `claude/hooks/*.sh` | `~/.claude/hooks/*.sh` |
| — | `~/Dev/Personal`, `~/Dev/Work` (created, never touched again) |

Machine-specific Zsh overrides belong in the ignored `zsh/local.zsh`, sourced
exactly once after all tracked modules.

### Configuration Notes

Git uses conditional includes for `~/Dev/Personal/` and `~/Dev/Work/`. The
tracked personal profile contains public identity data; work identity and local
signing overrides remain ignored machine-local files. `delta` follows terminal
or macOS light/dark appearance through `DELTA_THEME_MODE`.

`wezterm.lua` configures the retained WezTerm terminal, automatic appearance
switching, pane keybindings, and SSH tab titles. See
[`nvim/README.md`](nvim/README.md) for Neovim plugins, keybindings, Mason/LSP,
Tree-sitter parser, and formatter details.

`gh/config.yml` contains public GitHub CLI preferences only; authentication is
created by `gh auth login` outside the repository. Claude integration installs
the `create-post` skill and `check-docs-before-commit` hook while preserving
unrelated local Claude settings.

## Keeping the Repository Publishable

`.github/workflows/ci.yml` runs on every push to `main` and every pull request:

- `shellcheck` over the scripts, tests, and fixtures;
- `make test` on macOS, matching the platform the scripts target;
- `gitleaks` over the working tree **and the full history** (`fetch-depth: 0`).

Run the same secret scan locally before pushing anything sensitive:

```bash
gitleaks dir . && gitleaks git .
```

Three classes of content are kept out of the repository by `.gitignore`:
agent planning artefacts (`.superpowers/`, `docs/superpowers/`), machine-local
software manifests, and machine-local shell, Git, and Claude state.

If a credential ever does land in a commit, rotate it first. Removing it from
the current tree does not remove it from history, and rewriting published
history is a separate, deliberate decision.

## License

MIT
