# Manual Workstation Steps

A few baseline tools have no trusted, deterministic installer in this
repository and are installed by hand. `setup/manual-checks.tsv` is the
authoritative list — `make doctor` runs the probe in every row. Install each
tool from its own installer, and never copy application data from another Mac.

Machine-specific applications belong in the gitignored
`setup/manual-checks.local.tsv`, described in the README.

## Work Git Identity

Bootstrap deliberately does not create `~/.config/git/gitconfig-work` from the
example. A placeholder address satisfies `user.useConfigOnly`, so Git would
author work commits as `your-work-email@company.com` instead of refusing them.
While the file is absent Git refuses commits under `~/Dev/Work`, which is the
safe outcome. Write it yourself:

```bash
printf '[user]\n    email = you@work.example\n' > ~/.config/git/gitconfig-work
```

`~/.config/git/gitconfig-local` is optional and holds GPG or signing overrides.

## Logging In

The `auth` probes in `manual-checks.tsv` only report whether a session already
exists. These are the commands that create one:

| Tool | Command |
| --- | --- |
| 1Password CLI | `op signin` |
| GitHub CLI | `gh auth login` |
| Codex | `codex login` |
| Claude Code | follow the interactive prompt on first run |
| npm and other registries | their own interactive login |

Authentication files, tokens, and caches must never be added to this
repository.
