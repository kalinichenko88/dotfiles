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

## GitHub (always)

A commit message, a pull request, an issue, a workflow file — anything that
touches a repository's GitHub surface goes through the `github` skill. Invoke it
before the first `git commit`, `gh` call or workflow edit, not after: it carries
commit trailers, PR ownership and merge style, issue filing, keeping issues true
as the code moves, and action pinning.

Two rules stay here in full, because they have to fire when nobody is thinking
about GitHub at all.

**Out-of-scope findings become issues.** Anything worth fixing that is **not**
part of the current task — a bug, a latent defect, an improvement worth making
later — gets filed as an issue instead of being fixed inline or dropped in the
chat. Do not derail the task to fix it; do not ask first. The skill carries the
how: searching for duplicates first, one issue per finding, existing labels
only, and every number listed in the final report. Where there is no GitHub
remote or `gh auth status` fails, name the finding in the final report instead.

**Never add a `Co-Authored-By:` trailer** to a commit message — no Claude, no
model name, no `noreply@anthropic.com`.
