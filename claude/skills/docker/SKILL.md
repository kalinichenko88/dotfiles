---
name: docker
description: Use when writing or reviewing a Dockerfile or a compose file — adding a FROM line, an image under a service, a COPY --from another image — or choosing, pinning or bumping a base image.
---

# Docker

Every image a Dockerfile or a compose file names is the newest stable release,
looked up today, on the smallest base that runs the app, and pinned to that
exact version.

## Look the version up, never recall it

Training data lags the registry by dozens of releases, so a version from memory
is already old. Pick the release line first:

1. The project pins its runtime — `.nvmrc`, `engines`, `.python-version`,
   `requires-python`, the `go` line in `go.mod`, `.tool-versions` — and the
   image follows it.
2. Nothing pins it — the newest stable line, or the newest LTS line where the
   runtime has them. Never a `-rc`, `-beta`, `-alpha` or nightly.

```bash
# Release lines, newest first. `lts` is the date a line became LTS — a date
# still ahead means not yet. Product names: https://endoflife.date/api/all.json
curl -s https://endoflife.date/api/nodejs.json \
  | jq -r '.[:4][] | "\(.cycle) latest=\(.latest) lts=\(.lts) eol=\(.eol)"'

# Exact tags on that line, in the variant you want
curl -s 'https://hub.docker.com/v2/repositories/library/node/tags?page_size=100&name=<line>.' \
  | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+-alpine[0-9.]+$' | sort -V | tail -3

# Confirm the tag resolves before writing it down
docker buildx imagetools inspect node:<tag>
```

Official images live under `library/`; others under their namespace
(`getmeili/meilisearch`). For GHCR and other registries take the version from
the project's releases — `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`
— and confirm it with `imagetools inspect`.

## Pin exactly what you found

```dockerfile
FROM node:<x.y.z>-alpine<a.b>   # yes — the release and the OS release under it
FROM node:<x>-alpine            # no — the next pull is a different image
FROM node                       # no — no tag means latest
```

The same goes for every place an image is named: `FROM`, `COPY --from=<image>`,
`RUN --mount=from=<image>`, and `image:` in compose. `latest`, a bare name,
`lts`, `stable`, a major or minor alone, and a variant without its release
(`-alpine`, `-slim`) all float: a rebuild picks up a new image, and nothing in
the diff says so.

An image published without version tags — distroless — is pinned by digest,
`@sha256:…`. One whose tags carry a version but no OS release — `caddy` — is
pinned by the version alone. A project that already pins by digest everywhere
keeps doing so.

When compose pulls the project's own image from a registry, it names the tag CI
pushed — the commit SHA or the release — through a variable that fails when
unset, `image: ghcr.io/<owner>/<app>:${APP_IMAGE_TAG:?}`, never `:latest`.
Compose interpolates every file before merging them, so a dev override that
builds the image instead still fails without the variable: the dev entry point
sets it, `APP_IMAGE_TAG=dev`.

## An exact pin needs something that bumps it

A pinned tag no longer picks up the patches a floating one would have, so the
repository raises those bumps itself. Before finishing, look at what it has:

- `renovate.json` or another Renovate config — covered; its Dockerfile and
  compose managers are on by default.
- `.github/dependabot.yml` with `docker` and `docker-compose` entries whose
  directories reach every file you touched — covered.
- Anything else on GitHub — add the missing entries in the same change.
  `directories` takes globs, so one entry covers `docker/*` or `apps/*`:

```yaml
version: 2
updates:
  - package-ecosystem: docker
    directories: ["/", "/apps/*"]
    schedule:
      interval: weekly
  - package-ecosystem: docker-compose
    directory: /
    schedule:
      interval: weekly
```

Not on GitHub — name the missing updater in the final report.

## A database keeps its major

A service that keeps data — Postgres, MySQL, Redis with persistence — stays on
the major and the distribution its volume was created with: a floating tag
already in the file is pinned to the newest release inside that major. A new
major, or a move between Debian and Alpine, is a data migration — on-disk
format, collation — so ask before making it.

## The smallest base that runs the app

The final stage uses the first row that works:

| The app is | Final stage |
| --- | --- |
| A static binary — Go with `CGO_ENABLED=0`, Rust on musl | distroless `static-debian<N>:nonroot`, newest Debian it publishes |
| Node, Python, Ruby, a service in compose | the `-alpine` variant |
| A dependency ships glibc-only binaries | the `-slim` variant, with a comment naming that dependency |

Check the dependency before settling on Alpine — a Python wheel without a
`musllinux` build, a Node addon with glibc-only prebuilds — rather than
assuming either way.

The full image belongs in a build stage, and only when the build needs its
toolchain. Build there, copy the artifact into the final stage.

`scratch` has no CA certificates and no non-root user; use it only when the
binary makes no TLS calls and you add a `USER` yourself.

## `COPY . .` ships with a `.dockerignore`

A Dockerfile that copies the whole context, or a directory of it, has a
`.dockerignore` at the context root — written in the same change, not suggested.
It excludes at least:

- `.env*` and every other file holding secrets, leaving `.env.example` in
- `.git`
- installed dependencies — `node_modules`, `.venv`
- local build output — `dist`, `build`, `coverage`

Then read it the other way: a broad pattern such as `*.md` also drops files the
app reads at runtime, and those go back in with `!path`.

## The server receives SIGTERM

`docker stop` and every redeploy send SIGTERM to PID 1 and kill it ten seconds
later. A process running as PID 1 that registers no SIGTERM handler ignores the
signal, so each stop waits out the ten seconds and ends in SIGKILL, mid-request
or mid-write. So one of these holds for every long-running service:

- compose sets `init: true` on it, or the image's `ENTRYPOINT` starts it under
  `tini --`
- the app handles SIGTERM itself — name the file that does in a comment

An entrypoint script ends with `exec <server> "$@"`, so the server, not the
shell, is the process that gets the signal.
