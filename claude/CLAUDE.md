# Global instructions

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

Never add a `Co-Authored-By:` trailer to commit messages — no Claude, no
model name, no `noreply@anthropic.com`.

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
- List every issue you filed (with numbers) in the final report.
