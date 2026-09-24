---
name: github
description: Use when touching a repository's GitHub surface — writing a commit message, running `gh pr create` or merging a pull request, filing or updating an issue, picking an issue up to work on, checking whether a finding is already filed, or creating or editing a GitHub Actions workflow.
---

# Working with GitHub

Everything here needs `gh` authenticated against a GitHub remote. Where it is
not — `gh auth status` fails, or the remote is elsewhere — skip the step and say
so in the final report rather than inventing a substitute.

| Moment | What must happen |
| --- | --- |
| Writing a commit message | `type: one sentence`, at most 5 bullets under it, no `Co-Authored-By:` |
| `gh pr create` | `--assignee @me`; assign every issue it closes too |
| Merging | `gh pr merge --squash --delete-branch --body` with one bullet list for the whole branch |
| Finding something out of scope | Small, safe, needs no decision: fix it in this PR, list it in the description. Otherwise file an issue — search by identifier first |
| Filing next to an existing issue | Name the relation, and correct the other side |
| Picking an issue up | Read what it is wired to; re-check its `path:line`; take along settled issues on the same code |
| Editing a workflow | Pin `uses:` to the latest major; runtime ≥ host |

## Commits

A commit message is a typed subject line, and under it, at most, a short list of
what was done:

```
fix(hooks): make the docs hook read commands, not prose

- Add the newline to the separator class
- Replay two recorded pushes through the hook in tests/hooks_test.sh
```

The subject is `type: sentence` or `type(scope): sentence` — imperative, up to
100 characters, so the whole first sentence fits. The types, and the only ones:

| Type | Use for |
| --- | --- |
| `feat` | a capability the user did not have before |
| `fix` | behaviour that was wrong and is now right |
| `refactor` | a change with no visible behaviour change |
| `docs` | documentation only |
| `test` | tests only |
| `ci` | workflows and pipelines |
| `chore` | anything else: dependencies, tooling, housekeeping |

A change touching several kinds takes the type of the part the reader cares
about; `wip` is not a type and never reaches `main`.

The list, when there is one, comes after a blank line: one to five bullets, one
line each, each naming a thing that was done. The reasoning, the measurements
and the alternatives stay in the PR description. Nothing else goes below the
list.

Commit messages are English, in every repository — see *Code speaks English* in
the global prompt.

Never add a `Co-Authored-By:` trailer: no Claude, no model name, no
`noreply@anthropic.com`.

## Pull requests

Every PR opened with `gh pr create` carries an assignee — always pass
`--assignee @me`, so the authenticated account owns it. An unassigned PR has
nobody's name on it in the list view, which is how review requests get lost.

If the PR closes an issue — `Closes #12`, `Fixes #12` — assign that issue the
same way *before* the PR merges and closes it: `gh issue edit 12 --add-assignee
@me`. Once GitHub closes an issue automatically, nothing goes back to record who
did the work. An issue already assigned to someone else stays theirs: say so,
do not reassign.

The title and description follow the language the project already uses — read
the recent merged PRs and issues before writing, and match them. English is the
default only where there is nothing to match.

Merging is always `gh pr merge --squash --delete-branch`, with `--body` set to
one bullet list in the *Commits* shape covering every commit on the branch:
without it GitHub fills the squash commit from a repository setting, by default
every branch commit's full message in turn. One commit per PR keeps `main`
readable, and the branch has nothing left to say once it is in. Its subject is
the PR title — by default a one-commit branch gives that commit's subject
instead — so both take the same `type: sentence` shape.

## Filing an issue

Anything worth fixing that is **not** part of the current task — a bug, a latent
defect, an improvement worth making later — gets filed as an issue instead of
being fixed inline or dropped in the chat. Do not derail the task to fix it; do
not ask first.

**If it is small, safe and needs no decision, it goes into this PR instead** —
the Boy Scout Rule from the global prompt. All three, checked against the diff
you would write, not the feeling: it stays within a few lines, it changes
nothing another caller or user relies on, and there is only one way to do it — a
typo, a stale comment, a dead variable, a wrong `path:line` in a doc, a broken
link. Fix it now, in its own commit if it touches a file the task does not, and
list it in the PR description under **Also fixed** with a line per item, so the
reviewer knows which changes are not the task. An issue for a two-line fix costs
more than the fix. Fails any of the three — a design choice, a behaviour change,
a fix that needs its own test — and it is an issue, however small it looks.

**Search by identifier, not by your title.** `gh issue list --search "Parser"
--state all` finds every issue that names the symbol; the prose you were about
to write finds only issues someone happened to phrase your way — and on a
tracker written in another language, nothing at all. Closed counts too: a
finding already filed and rejected does not need filing again.

- One issue per finding. Title states the problem, body says where it is
  (`path:line`), how it shows up, and why it was out of scope here.
- Label it from the labels the repository already has — `gh label list` first,
  then `--label` with the ones that fit. Never invent a new label; if nothing
  fits, file it unlabelled.
- List every issue you filed (with numbers) in the final report.

## An issue is a document too

*Docs move with the change* applies to the tracker. An issue goes stale the
moment the code moves under it, and GitHub does not notice: it backlinks a
reference automatically, but nothing corrects the text on either side.

**Filing one next to an existing issue.** Name the relation in the body —
`Related to #12`, `Blocks #12`, `Supersedes #12` — and fix the other side in the
same breath: edit its body so the next agent reads something true, and leave a
one-line comment saying what moved and why. GitHub keeps the edit history, so
nothing is lost by correcting the text in place. A duplicate is closed against
the survivor, never left standing as a second opinion.

**Taking one into work.** Read it, then list what points at it — the timeline
carries every cross-reference, including the ones its own body never mentions:

```bash
gh api repos/{owner}/{repo}/issues/12/timeline --paginate \
  --jq '.[] | select(.event == "cross-referenced")
        | "\(if .source.issue.pull_request then "PR" else "issue" end) \(.source.issue.number) \(.source.issue.state) \(.source.issue.title)"'
```

`--paginate` is not optional: the timeline pages at 30 events, and on a
well-linked issue the newest references are exactly the ones that fall off the
first page. Read in full the open issues, the PRs that touched the same code,
and any closed issue whose outcome the task leans on; titles and state are
enough for the rest.

Then check the issue's own `path:line` citations against the current tree before
believing them — a line number is the first thing to rot — and correct them in
the issue as the first act of the work.

**Taking neighbours along.** Before the first edit, search the open issues for
every file and symbol the task will change — by identifier, as for a finding:
`gh issue list --state open --search "verify_target"`. The issue in hand stays
the task; another one rides along only if it passes all four checks, against
the diff you would write:

- **Same file** — it changes a file the task already changes, in any function.
  The same topic in another file is another PR.
- **Settled** — its body already says what to do; nothing in it waits on a
  decision.
- **Smaller** — its share of the diff is smaller than the task's.
- **Separable** — dropping it leaves the task whole, so a reviewer can ask for
  it to be split out and lose nothing but a line in the description.

Then add up the ones that passed: while their total is not smaller than the
task's diff, drop the largest, one at a time. Past that line the PR title
describes the minority of the change.

Nothing passes: ship the task alone — that is the usual case, not a failure to
look. A ride-along is a whole issue, not a Boy Scout fix: a bug brings its own
test, it is assigned like the task, and the PR description closes it under
**Also closes**, one line per issue with its own keyword — `Closes #15` —
because GitHub closes only the numbers a keyword precedes.

**Finishing.** The PR closes it and every ride-along, and the same pass updates
every sibling issue whose text the change just falsified.

Measured on a live tracker: of the 100 newest issues, 4 bodies had ever been
edited; 5 open issues still cited a file the schema migration had deleted; one
pointed 23 lines away from the code it described, at a closing brace. Every one
of them was correctly cross-linked — the graph was never the problem.

## GitHub Actions

When creating or editing CI workflows, in any project:

1. **Pin every `uses:` to the latest available major.** Don't trust memory —
   verify against the GitHub API:
   `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`, and confirm the
   floating major tag exists:
   `gh api repos/<owner>/<repo>/git/matching-refs/tags/v --jq '[.[].ref|sub("refs/tags/";"")]|map(select(test("^v[0-9]+$")))'`.
   Pin to the floating major (e.g. `actions/checkout@v7`), not an exact patch.

2. **Never pin a CI language runtime below the host dev machine.** The CI
   version must be **>= the version installed on the current machine** (e.g.
   `node --version`, `bun --version`). Match the host major by default; never go
   lower. Re-check whenever touching workflow runtime versions.

Apply both whenever adding or reviewing CI, even if not explicitly asked.
