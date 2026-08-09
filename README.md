# dotfiles

Reproducible macOS workstation setup for Apple Silicon: Homebrew packages,
pinned runtimes, and the configuration for Git, Zsh, Neovim, WezTerm, GitHub
CLI, Starship, Docker, and Claude Code.

Nothing here ever uninstalls software. Every command is idempotent and refuses
to overwrite a file it does not manage.

## Install on a new Mac

**1. Prerequisites and clone**

```bash
curl -fsSL https://raw.githubusercontent.com/kalinichenko88/dotfiles/main/scripts/preinstall.sh | bash
```

That installs Apple's Command Line Tools, which provide `git`, and clones this
repository to `~/Dev/Personal/dotfiles`. Rerunning it is harmless.

The clone uses **HTTPS on purpose**: the SSH key lives in 1Password, which the
bootstrap installs from the `Brewfile` inside this repository, so requiring SSH
here would be a loop with no way in. Switching the remote to SSH is the last
step, after 1Password is signed in.

By hand, if you prefer:

```bash
xcode-select --install          # skip if already present
git clone https://github.com/kalinichenko88/dotfiles.git ~/Dev/Personal/dotfiles
cd ~/Dev/Personal/dotfiles
```

**2. Preview, then apply**

```bash
DRY_RUN=1 INSTALL_HOMEBREW=1 make bootstrap    # prints every command, changes nothing
INSTALL_HOMEBREW=1 make bootstrap
```

`INSTALL_HOMEBREW=1` is only needed when Homebrew is absent; installing it is
never inferred from a plain bootstrap request. Bootstrap runs in this order:

1. platform check — Apple Silicon macOS with Command Line Tools;
2. Homebrew, then `Brewfile` and `Brewfile.local` if present;
3. pinned NVM, the exact Node version, UV tools;
4. the `~/Dev` project directories, then all configuration;
5. strict `doctor` verification;
6. `~/.config/dotfiles/bootstrap-complete` — written only after 1-5 pass.

Software already installed by hand does not stop the run: `brew bundle install`
adopts an existing `/Applications/Name.app` instead of failing. Note that it
adopts even when the installed version differs from the cask's, and records the
cask's version — so an adopted app that is behind looks current to
`brew upgrade`. `brew reinstall --cask <token>` fixes that one.

**3. Resolve conflicts, if it stops**

If an unmanaged file already sits at a target path, bootstrap stops and names
it. Inspect it, then rerun with backups enabled:

```bash
FORCE=1 make config-install     # moves each conflict to <name>.backup.<timestamp>
```

**4. Install what Homebrew cannot**

The run prints the checklist from `setup/manual-checks.tsv` — the CLIs that ship
with their own installers. Install those, then log in using
[`setup/manual-apps.md`](setup/manual-apps.md).

**5. Verify**

```bash
make doctor
```

On first Neovim launch, install the parsers listed in
[`nvim/README.md`](nvim/README.md).

**6. Switch the remote to SSH**

Once 1Password is signed in and its SSH agent is on, this machine can push:

```bash
git remote set-url origin git@github.com:kalinichenko88/dotfiles.git
```

## Update an existing Mac

```bash
git pull
make update
```

`make update` refreshes Homebrew, reapplies both Brewfiles, the pinned Node and
UV manifests and every configuration unit, upgrades packages, and finishes with
a `doctor` pass. It applies everything that pass then verifies, so a pull that
bumps any manifest needs no second command. Casks that update themselves are left alone — Homebrew skips them by
design, and this repository does not use `--greedy`.

Then look at what this machine has that no manifest declares:

```bash
make inventory
```

For each entry decide where it belongs: `Brewfile` if every machine should get
it, `Brewfile.local` if only this one. Removing software is always manual.

To reinstall configuration without touching packages:

```bash
make config-install              # everything
make config-nvim                 # one unit
```

## Commands

| Command | Purpose |
| --- | --- |
| `make bootstrap` | Full provisioning: brew, tools, config, doctor, marker |
| `make bootstrap-brew` | Apply `Brewfile` and, when present, `Brewfile.local` |
| `make bootstrap-tools` | Pinned NVM/Node and UV tools |
| `make config-install` | Install every configuration unit |
| `make config-<unit>` | Install one unit |
| `make update` | Refresh, reapply manifests, upgrade, then doctor |
| `make doctor` | What the manifests declare and this machine lacks |
| `make inventory` | What this machine has and no manifest declares |
| `make git-check` | Active `user.name`/`user.email` and their sources |
| `make test` | Shell integration and regression tests |

Units: `dev-dirs`, `git`, `ssh`, `zsh`, `nvim`, `wezterm`, `gh`, `starship`,
`docker`, `claude`.

## Safety

- `DRY_RUN=1` prints mutation commands instead of running them.
- Existing configuration is never replaced by default; a conflict is an error.
- `FORCE=1` backs the conflicting file up to a timestamped sibling first.
- The work Git identity is never created from the example: a placeholder
  address would satisfy `useConfigOnly` and author commits as itself. Until you
  write `~/.config/git/gitconfig-work`, Git refuses commits under `~/Dev/Work`
  and doctor warns.
- Docker config and Claude settings are merged with `jq` rather than replaced,
  because other tools write to those files too. Unrelated keys survive, and a
  file that does change is backed up first.

## Machine-specific software

This repository is public, so software belonging to one machine is never
tracked. Declare it in the gitignored siblings; bootstrap, update, and doctor
read them automatically when present:

| File | Holds |
| --- | --- |
| `Brewfile.local` | extra `tap`/`brew`/`cask` lines for this machine |
| `setup/cask-apps.local.tsv` | `cask-token<TAB>/Applications/Name.app` |
| `setup/manual-checks.local.tsv` | `app<TAB>Display Name<TAB>/Applications/Name.app` |
| `~/.ssh/config.local` | every `Host` entry: names, addresses, jump hosts |

`make test` fails if machine-specific casks or an application inventory
reappear in the tracked manifests.

## What doctor reports

Required failures: missing taps, formulae, or casks; a wrong Node or UV version;
missing tracked configuration; a work Git identity still holding the template's
placeholder address. Warnings: available upgrades, unsupported manual
applications, authentication state, and a manual CLI that is not installed yet —
those ship their own installers, so their absence must not fail a first run. A
manual CLI that *is* installed but fails its probe stays a required failure.

For casks, doctor accepts either a Homebrew receipt or the expected application
bundle from `setup/cask-apps.tsv`, so an app installed by hand is not
reinstalled just to change package-manager ownership.

Files other tools also write — `~/.docker/config.json` and
`~/.claude/settings.json` — are merged rather than replaced, and doctor checks
that the tracked keys are present rather than that the file matches exactly.
Docker registry credentials and Claude hooks you added yourself survive.

## Configuration destinations

| Source | Target |
| --- | --- |
| `git/gitconfig` | `~/.config/git/config` |
| `git/gitconfig-personal` | `~/.config/git/gitconfig-personal` |
| `ssh/config` | `~/.ssh/config` |
| `zsh/zshrc` | `~/.zshrc` |
| `nvim/` | `~/.config/nvim` |
| `wezterm.lua` | `~/.wezterm.lua` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `docker/config.json` | `~/.docker/config.json` (merge) |
| `claude/skills/*` | `~/.claude/skills/*` |
| `claude/hooks/*.sh` | `~/.claude/hooks/*.sh` |
| `claude/hooks-config.json` | `~/.claude/settings.json` (merge) |
| — | `~/Dev/Personal`, `~/Dev/Work`, `~/Dev/Open Source` (created once) |

Git switches identity by path: `~/Dev/Personal/` and `~/Dev/Open Source/` use
the tracked personal profile, `~/Dev/Work/` uses a gitignored work file created
from an example. Every directory bootstrap creates has a matching rule, and
`make test` fails if one is ever added without it.

No email is set at the top level, and `user.useConfigOnly = true`. Outside
those directories Git refuses to commit rather than inventing
`user@hostname` — with more than one identity in play, a wrong address is
worse than an error. Set `user.email` in the repository, or clone it under
`~/Dev`.

Zsh loads every tracked module from `zsh/`, then the ignored `zsh/local.zsh`
exactly once, last. Shell behaviour — history, completion, keybindings — lives
in `zsh/options.zsh`; there is no framework.

See [`nvim/README.md`](nvim/README.md) for Neovim plugins, keybindings, LSP, and
formatters. `gh/config.yml` holds public preferences only, applied with
`gh config set` rather than symlinked, because gh writes its own state into
that file. `gh auth login` keeps credentials outside this repository.

## Keeping the repository publishable

`.github/workflows/ci.yml` runs on every push to `main` and every pull request:
`shellcheck` over scripts, hooks, tests and fixtures; `make test` on macOS;
`gitleaks` over the working tree **and the full history**.

The same scan locally:

```bash
gitleaks dir . && gitleaks git .
```

`.gitignore` keeps out three classes of content: agent planning artefacts
(`.superpowers/`, `docs/superpowers/`), machine-local software manifests, and
machine-local shell, Git, and Claude state.

If a credential ever lands in a commit, rotate it first. Deleting it from the
working tree does not remove it from history, and rewriting published history
is a separate, deliberate decision.

## License

MIT
