# CLAUDE.md

Guidance for Claude Code working in this repository. User-facing install and
update instructions live in [README.md](README.md) — do not restate them here.

## Repository Overview

Personal macOS dotfiles: configuration for Git, Zsh, Neovim, WezTerm, GitHub
CLI, Starship, Docker, and Claude Code, plus the scripts that provision and
verify a workstation. Most of it is configuration symlinked into place;
`scripts/` is the only real code.

**This repository is public.** Never track secrets, hostnames, personal
application inventories, or agent planning documents (specs, plans, review
diffs). Machine-specific software belongs in the gitignored `Brewfile.local`,
`setup/cask-apps.local.tsv`, and `setup/manual-checks.local.tsv`.

## Code Layout

- `scripts/preinstall.sh` — runs *before* this repository exists locally, piped
  from raw.githubusercontent. Command Line Tools, then an **HTTPS** clone: the
  SSH key comes from 1Password, which the bootstrap installs from the Brewfile
  in here, so requiring SSH to clone would be a loop. Never change it to `git@`.
- `scripts/bootstrap.sh {all|brew|tools|config [unit]|update|cleanup|units}` —
  the only thing that writes anything. Steps run through `run_step`: a failure is recorded,
  the run continues, and `report_failed_steps` exits non-zero at the end. Note
  that `run_step` suspends `set -e` inside the function it calls, so a function
  invoked that way must return non-zero explicitly where it matters (see
  `verify_target`, which would otherwise write its marker after doctor failed).
  `cleanup` is the only subcommand that uninstalls; it feeds `brew bundle
  cleanup` the tracked and `.local` manifests concatenated, because pointing it
  at the tracked file alone would remove everything the machine declares for
  itself, and it refuses outright if that combined manifest is empty.
- `scripts/doctor.sh` — read-only verification, exit 1 on required failures
- `scripts/inventory.sh compare` — read-only drift report, the reverse of doctor
- `scripts/lib/common.sh` — link/copy/backup primitives, `dotfiles_manifest`
  (tracked manifest plus its `.local` sibling), `dotfiles_links` (the symlink
  table), `dotfiles_brewfile_records` (the one Brewfile parser),
  `dotfiles_merge_json` (tracked JSON into a file other tools also write),
  `dotfiles_make_tmp`, `dotfiles_run_with_timeout` (macOS ships no `timeout(1)`;
  without it a hanging auth probe hangs doctor)
- `setup/links.tsv` — `unit`, `label`, `source`, `target-under-home`. bootstrap
  installs these rows, doctor verifies the same rows. A new symlinked config is
  a line here, not an edit in two scripts.
- `tests/*_test.sh` — plain bash, fixtures in `tests/fixtures/bin`, run by
  `make test`

Config units for `make config-<unit>`: `dev-dirs`, `git`, `ssh`, `zsh`, `nvim`,
`wezterm`, `gh`, `starship`, `docker`, `claude`. The ordered list lives once, in
`CONFIG_UNITS` in `scripts/bootstrap.sh`; the Makefile and the tests ask for it
with `./scripts/bootstrap.sh units`. A unit with a `config_<unit>` function runs
it; anything else is defined entirely by its rows in `setup/links.tsv`.

CI (`.github/workflows/ci.yml`) runs shellcheck, `make test` on macOS, and
gitleaks over the working tree and the full history.

## Invariants the tests enforce

Breaking any of these fails `make test`, so fix the cause rather than the test:

- `git/gitconfig` must set `useConfigOnly = true` and must **not** set a
  top-level `email`. Identity comes only from `includeIf`.
- Every directory `config_dev_dirs` creates needs a matching `includeIf` rule.
- The tracked `Brewfile` and `setup/cask-apps.tsv` must stay free of
  machine-specific casks; `setup/manual-checks.tsv` must contain no `app` rows.
- `Brewfile.local` and the `.local` TSVs must stay untracked.
- Tracked Zsh files must contain no absolute `/Users/<name>` paths, and no
  pinned `python@<version>` — the PATH entry is globbed so a Brewfile bump
  needs no edit.
- Every tap the `Brewfile` declares must be passed to `brew trust --tap` before
  `brew bundle` runs. Homebrew refuses untrusted third-party taps and bundle
  aborts on the first one, which blocks a first run entirely.
- A failing config unit must not stop the units after it: `ssh` precedes `zsh`,
  and stopping there leaves a new machine with no shell configuration.

Two rules that look like redundancy but are not:

- `~/.docker/config.json` and `~/.claude/settings.json` are **merged**
  (`dotfiles_merge_json`), never copied. `~/.config/gh/config.yml` is applied
  with `gh config set` and never symlinked, for the same reason: gh writes its
  own state into it, and a symlink made the repository dirty on first use. Other tools write to both — `docker
  login` stores registry credentials there, and the user may have their own
  Claude hooks. Doctor checks `contains`, not equality, for the same reason.
  Turning either back into a copy or an equality check destroys user state and
  leaves doctor with no state that can ever be green.
- A manual-install CLI that is missing is a **warning**; one that is installed
  but fails its probe is a failure. Bootstrap only prints the checklist for
  those tools, so making absence a failure means a first run can never finish.

## Architecture

### Git identity

Conditional includes switch identity by repository location:

- `git/gitconfig` — `includeIf` directives, `user.name`, `useConfigOnly`, no email
- `git/gitconfig-personal` — email for `~/Dev/Personal/*` and `~/Dev/Open Source/*`
- `~/.config/git/gitconfig-work` — email for `~/Dev/Work/*`. **Never created by
  bootstrap**: a placeholder satisfies useConfigOnly, so Git would author work
  commits as it. Absent is the safe state — Git refuses instead.
- `~/.config/git/gitconfig-local` — GPG and signing overrides, also hand-written

Outside those three directories Git refuses to commit rather than inventing
`user@hostname`. With a personal and a work address in play, a wrong author is
worse than an error, so "Author identity unknown" there is correct behaviour.

### Zsh

`zsh/zshrc` sources every `zsh/*.zsh` alphabetically, then the gitignored
`zsh/local.zsh` exactly once, last. There is **no framework** — Oh My Zsh was
removed because starship already owned the prompt and its `git` plugin silently
overrode aliases declared in `aliases.zsh`.

- `aliases.zsh` — git, nvim, and claude shortcuts
- `options.zsh` — history, `setopt` list, `bindkey -e` (without it zsh infers vi
  mode from `$EDITOR`), `compinit`
- `path.zsh` — Homebrew shellenv, NVM, optional app-bundled CLIs
- `starship.zsh` — prompt, loaded last

`options.zsh` adds Homebrew's function directory to `fpath` itself rather than
depending on `path.zsh` loading first.

### Neovim

Neovim 0.11+ with lazy.nvim.

```
nvim/
├── init.lua              # requires core/*, plugin, command
└── lua/
    ├── plugin.lua        # lazy.nvim bootstrap
    ├── command.lua       # CopyRelPath, CopyFileName, CopyGitBranch
    ├── autocommands.lua
    ├── core/             # options.lua, keymaps.lua, filetypes.lua
    └── plugins/          # one file per plugin, auto-imported
```

1. Uses `vim.lsp.config()` (0.11+), not `require('lspconfig').setup()`
2. TreeSitter uses the rewrite API — `require('nvim-treesitter').install()` plus
   manual highlight autocmds
3. Format-on-save via conform.nvim; Prettier is disabled in ts_ls and eslint to
   avoid conflicts
4. Theme follows macOS appearance on startup and every `FocusGained`
5. Leader is Space
6. Word wrap auto-enabled for `markdown` and `text`

To add a plugin: create `nvim/lua/plugins/<name>.lua` returning a lazy.nvim
spec, then restart. See [nvim/README.md](nvim/README.md) for plugins,
keybindings, Mason/LSP, and formatters.

### Claude Code skills and hooks

`claude/skills/*` symlink to `~/.claude/skills/`, `claude/hooks/*.sh` to
`~/.claude/hooks/`, and `claude/hooks-config.json` is merged into
`~/.claude/settings.json` with `jq` — unrelated keys survive, and changing an
existing file requires `FORCE=1`. Installing then prunes dangling links in
those two directories with `dotfiles_prune_orphan_links`, so renaming a hook
does not leave the old one behind on every other machine; links pointing
outside this repository are the user's own and are never touched.

- Skill `create-post` — English blog posts from rough Russian drafts
- Hook `check-docs-before-push` — PreToolUse hook that blocks `git push`
  until CLAUDE.md and README.md have been reviewed, using a session-scoped temp
  flag so the retry passes

### WezTerm

Single-file `wezterm.lua`: dark/light switching on macOS appearance, Cmd+D pane
splits, Monaco DemiBold with Menlo and Nerd Font fallbacks, and a tab title
showing the basename of the pane's working directory.

### ssh-remote

Nothing of it is on `main`. The `ssh()` wrapper, `zsh/ssh-remote.zsh`, the
vendored mini.nvim bundle, the `make ssh-remote-*` targets, and the WezTerm
`ssh_host` tab title all live on the unmerged `feat/ssh-remote-nvim` branch.
Do not look for them here.

## Conventions

- Lua is formatted by stylua on save, single quotes
- `.editorconfig` sets 2-space indentation and line endings for everything else
- Shell scripts must pass `shellcheck`. Two suppressions are legitimate and
  already used: `SC1091` for runtime-resolved `source` paths, and `SC2016` for
  single-quoted jq programs, where `$source` is a jq variable rather than a
  shell one. Anything else means fixing the code, not silencing the check.

## Gitignored files

Never track any of these, and never suggest adding one to a commit:

| File | Why |
| --- | --- |
| `git/gitconfig-work` | Work email address — belt and braces; nothing writes it |
| `git/gitconfig-local` | GPG and signing keys — same |
| `zsh/local.zsh` | Per-host tweaks, hostnames |
| `~/.ssh/config.local` | SSH hosts, addresses, jump paths (outside the repo) |
| `Brewfile.local` | Software for this machine only |
| `setup/cask-apps.local.tsv` | Bundle paths for machine-local casks |
| `setup/manual-checks.local.tsv` | Personal application inventory |
| `docs/superpowers/`, `.superpowers/`, `.ralphex/` | Agent specs, plans, review diffs |
| `.claude/` | Local Claude state |

The two `git/` paths are never written by anything: the real files live at
`~/.config/git/gitconfig-work` and `~/.config/git/gitconfig-local`, hand-written
from the `*.example` templates. The ignore rules stay because an older bootstrap
did symlink them into this public repository, and `check_private_git_file` in
`scripts/doctor.sh` now fails on exactly that state. The `.local` manifests are
read automatically by bootstrap, update, and doctor — see `dotfiles_manifest` in
`scripts/lib/common.sh`.

## Troubleshooting

**Git identity not switching, or "Author identity unknown"**
Verify the repository sits under `~/Dev/Personal/`, `~/Dev/Work/`, or
`~/Dev/Open Source/`; nothing outside them gets an email. `make git-check`
shows the active address and which file supplied it.

**Zsh completion or history broken**
It all comes from `zsh/options.zsh`; there is no framework to blame.
`echo ${_comps[git]}` should print `_git`.

**Neovim LSP or formatting**
`:Mason` for servers, `:LspInfo` for attachment, `:ConformInfo` for formatters,
`:checkhealth nvim-treesitter` for parsers.
