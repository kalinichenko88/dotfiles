# Manual Workstation Steps

These items belong to the shared baseline but have no trusted, deterministic
installer in this repository. Install them manually and use the listed probe to
verify them. Do not copy application data from another Mac.

## Standalone and Application-Bundled CLIs

| Tool | Verification |
| --- | --- |
| Claude Code | `claude --version` |
| OpenCode | `opencode --version` |
| Cursor Agent | `agent --version` |
| LM Studio CLI | `lms --version` |

## Authentication Checklist

Authenticate locally after installation. Never add the resulting files to this
repository:

- 1Password CLI: `op signin`
- GitHub CLI: `gh auth login`
- Codex: `codex login`
- Claude Code: follow the interactive login prompt
- npm or other package registries: use their interactive login commands

## Machine-Specific Software

This repository is public, so per-machine software is never tracked. Declare it
in the gitignored files instead; `bootstrap`, `update` and `doctor` pick them up
automatically when present:

| File | Holds |
| --- | --- |
| `Brewfile.local` | `brew`/`cask`/`tap` lines for this machine only |
| `setup/cask-apps.local.tsv` | `cask-token<TAB>/Applications/Name.app` |
| `setup/manual-checks.local.tsv` | `app<TAB>Display Name<TAB>/Applications/Name.app` |

Mac App Store applications belong in `setup/manual-checks.local.tsv` as well.
This repository intentionally does not automate App Store authentication.
