# Global instructions

## The repository's own gate (always)

Before claiming a task done, run the repository's own check command — the single
target that chains lint, typecheck and tests (`make check`, `bun run check`, the
`check`/`ci` script in `package.json`, whatever CI calls). If there is none, run
the closest equivalent and say so. Report the actual outcome — "should pass" is
not a result.

## A bug fix ships with its test (always)

Every bug fix carries the test that would have caught it: written before the
fix, seen failing against the unfixed code, passing after. It asserts the
behaviour that was reported, not the internals of the fix.

If the bug shows on several surfaces, guard each one. Fixing the surface the
report named and leaving its siblings is how the bug comes back under a new
name.

**The input comes from the source, not from your head.** Red-then-green proves
the test exercises the code. It does not prove the case exists. A guard built on
an input the real source never emits goes green forever while the real shape
stays unchecked — and the fix underneath it can be doing nothing, or harm.

So before the report is even believed, count it: pull a sample of real payloads
and say how many carry the shape. Zero means the fix does not need to exist, and
that is the finding. Then write the case against a recorded payload — whitespace,
pretty-printing and all — not a string typed to make the assertion pass.

Measured, the one time this was skipped: a "list items run together" bug, filed
off a hand-written `<li>a</li><li>b</li>`, tested green, shipped. The sources
turned out never to emit two block tags without whitespace between them — 0 of
100 bodies — so the fix changed no table it claimed to fix and put a blank line
inside 6 of 10 real lists. The test was green over data that never moved.

## Use the platform before reaching past it (always)

Whatever the project runs on — Node, Bun, Deno, Go, the browser — check what its
standard library already does at the version the project pins, before writing a
helper by hand or adding a dependency. Runtimes ship faster than training data:
verify against current docs (context7, the release notes), not memory, and take
the newest API the pinned version actually supports.

`Intl.NumberFormat` instead of a hand-written currency formatter,
`structuredClone` instead of a deep-clone package, `slices`/`maps` instead of a
copied generic helper. A dependency earns its place only where the platform has
no answer — name the API you checked before concluding that.

## Code speaks English (always)

Inside the code everything is English: identifiers — variables, functions,
types, files, branches — and every comment, docstring and TODO. This holds in
every project, whatever language the team speaks. Mixed-language symbols are
ungreppable and split a codebase into dialects.

Another language appears only in the data layer: user-facing copy, translation
catalogues, fixtures and seed data, and values that simply *are* text in that
language. The key stays `greeting.ru`; the string it holds does not have to be
English.

Commit messages are English too, in every repository. They are the log of the
code: `git log` and `git blame` are read long after the team that wrote them,
and a history in two languages is as ungreppable as a codebase in two.

The rest of the prose — README, docs, issues, PR titles and descriptions — is
the project's own call. Match what the repository already does rather than
imposing English on it.

## Docs move with the change (always)

A change that alters user-visible behaviour, a public contract, or how the thing
is installed updates the documents that describe it — in the same change, not a
follow-up. README, the project's instruction file, API docs, ADRs: whichever
ones now say something false.

- Before finishing, name the docs the change touched, or say "docs impact: none"
  with a one-line why. Saying nothing is not an answer.
- A follow-up is allowed only for a broader sweep the change merely brushes
  against — never for the document that describes the very behaviour changed.

## CI / GitHub Actions hygiene (always)

When creating or editing CI workflows (GitHub Actions, any project):

1. **Pin every `uses:` to the latest available major.** Don't trust memory — verify against the GitHub API:
   `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`, and confirm the floating major tag exists:
   `gh api repos/<owner>/<repo>/git/matching-refs/tags/v --jq '[.[].ref|sub("refs/tags/";"")]|map(select(test("^v[0-9]+$")))'`.
   Pin to the floating major (e.g. `actions/checkout@v7`), not an exact patch.

2. **Never pin a CI language runtime below the host dev machine.** The CI version must be **>= the version installed on the current machine** (e.g. `node --version`, `bun --version`). Match the host major by default; never go lower. Re-check whenever touching workflow runtime versions.

Apply both whenever adding or reviewing CI, even if not explicitly asked.

## Handling code-review findings (always)

After any code review — `/code-review`, a review subagent, or a human's
comments — follow this order, without being asked:

1. **Verify each finding yourself before acting on it.** Reproduce it against
   the real code or in a browser. Reviewers report findings that are wrong,
   stale, or right for the wrong reason, and a confident wrong fix is worse
   than the original defect. Say plainly which findings did not survive.
2. **Fix the unambiguous ones immediately.** Real bugs, dead code, accessibility
   and contrast failures, code that contradicts its own documentation, wrong
   numbers in docs. No need to ask.
3. **Ask before anything that is a judgment call**, with concrete options and a
   recommendation: changes to visual appearance or feel, trade-offs with no
   objectively right answer, and anything widening the scope of the current
   work. Prefer showing the options (rendered variants, screenshots, before and
   after numbers) over describing them.
4. **Fix at the root, not at the symptom.** If the same defect exists in sibling
   call sites or in a shared token, fix it there and say how many places it
   covered.
5. **Report honestly.** State what was fixed, what was deliberately skipped and
   why, and any side effect a fix introduced elsewhere.

## Commits (always)

Commit messages are written in English — see *Code speaks English* above.

Never add a `Co-Authored-By:` trailer to commit messages — no Claude, no
model name, no `noreply@anthropic.com`.

## Pull requests (always)

Every PR opened with `gh pr create` carries an assignee — always pass
`--assignee @me`, so the authenticated account owns it. An unassigned PR has
nobody's name on it in the list view, which is how review requests get lost.

If the PR closes an issue — `Closes #12`, `Fixes #12` — assign that issue the
same way *before* the PR merges and closes it: `gh issue edit 12 --add-assignee
@me`. Once GitHub closes an issue automatically, nothing goes back to record who
did the work.

The title and description follow the language the project already uses — read
the recent merged PRs and issues before writing, and match them. English is the
default only where there is nothing to match.

Merging is always `gh pr merge --squash --delete-branch`. One commit per PR
keeps `main` readable, and the branch has nothing left to say once it is in.

- Already assigned to someone: leave it alone, say so, do not reassign.
- `gh` not authenticated, or no GitHub remote: skip all of it and mention it.

## Out-of-scope findings become issues (always)

Anything worth fixing that is **not** part of the current task — a bug, a
latent defect, an improvement worth making later — gets filed as a GitHub
issue instead of being fixed inline or dropped in the chat. Do not derail the
task to fix it; do not ask first.

- Only when the repository has a GitHub remote and `gh auth status` passes.
  Otherwise mention the finding in the final report and move on.
- Search first — `gh issue list --search "<keywords>" --state all` — and skip
  filing if it is already there.
- One issue per finding. Title states the problem, body says where it is
  (`path:line`), how it shows up, and why it was out of scope here.
- Label it from the labels the repository already has — `gh label list` first,
  then `--label` with the ones that fit. Never invent a new label; if nothing
  fits, file it unlabelled.
- List every issue you filed (with numbers) in the final report.
