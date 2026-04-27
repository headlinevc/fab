# fab

End-to-end feature fabrication for [Claude Code](https://claude.com/claude-code) — turn a rough idea into a tested, reviewed, shipped feature with **four human touchpoints**.

```
/fab
```
> "Add a CSV export button to the customers table"

Fab will:
1. **Challenge** the framing — is CSV export the right answer, or is the real problem data portability?
2. Lock a direction with you, write a full spec, set up an isolated worktree, dispatch a Staff Engineer to implement, run a slate of advisor reviews (UX, API, security, etc.), run a standard + adversarial code review, take screenshots, and hand back a running localhost.
3. After you say "ship it": push, PR, fix CI, fix automated review comments, audit docs, leave a retro.
4. Optional: say "land it" to merge.

## Install

This is a [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills). Drop it into your skills directory or load it as part of a plugin.

### Option 1 — copy the skill

```bash
git clone https://github.com/headlinevc/fab.git ~/.claude/skills/fab
```

Restart Claude Code. `/fab` should appear as an available command.

### Option 2 — as a plugin

If you maintain a [plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins), add `fab` as a skill in any plugin and ship it the usual way. The skill is fully self-contained — no other skill dependencies.

### Activate the pipeline-gate hook

Fab uses a PreToolUse hook to enforce review/commit ordering. The skill installs the hook script automatically on first run, but you'll need to register it in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/fab-gate.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

The hook is silent unless a `.fab` file exists in the worktree, so it doesn't interfere with normal work.

## Configuration

Fab reads optional project conventions from your repo's `CLAUDE.md`. Add any of these to keep fab fully autonomous:

```markdown
Default team: ABC                    # ticket-tracker team / project key
Audience: <one sentence>             # who uses this product (shapes UX/voice critique)
Stack: rails+react                   # optional override; otherwise auto-detected
Ticket tracker: linear | github | none
```

If a value is missing, fab auto-detects when it can (stack via lockfiles, tracker via available CLIs) and asks you once if it can't.

## What's required

**Required:**
- `git` — for worktrees and commits.
- [Claude Code](https://claude.com/claude-code) — to run skills.

**Recommended:**
- [`codex`](https://github.com/openai/codex) CLI — for second-opinion code review (Stages 4.6 and 4.7). Fab will refuse to commit without it unless you skip those stages explicitly.
- [`gh`](https://cli.github.com/) — for PR creation and automated-review fix loops in Stage 7.
- A browser-automation tool (Playwright, Puppeteer, headless Chrome) — for visual QA in Stage 4.9. Skipped if absent.

**Optional:**
- [`linear`](https://linear.app/) CLI — if you use Linear as your tracker.
- `overmind` + a `Procfile.dev` — if your repo uses dev slots for parallel work.

## How it works

Fab orchestrates 9 stages with 4 human touchpoints. The full protocol is in [`SKILL.md`](SKILL.md). Stages 4.6 and 4.7 (standard + adversarial code review) and the commit step are gate-enforced — fab cannot skip them, even if instructed to, because the `fab-gate.sh` hook physically blocks `git commit` and `gh pr create` unless required state is recorded in `.fab`.

| Stage | Who | What |
|-------|-----|------|
| 0 | auto | Bootstrap fab-gate hook |
| 1 | you + AI | Product challenge — pressure-test the idea |
| 2 | auto | Spec — write tracker entry, assemble advisor team |
| 3 | you | Approve spec |
| 4 | auto | Implementation — worktree, Staff Engineer, advisors, code reviews, visual QA |
| 5 | auto | Notify with screenshots |
| 6 | you | Test, give feedback |
| 7 | auto | Ship — PR, CI, automated-review fixes |
| 8 | auto | Doc audit |
| 9 | auto | Retro |

## Self-contained, with extraction hints

This skill is intentionally a single self-contained file. Several substantial protocols are inlined that could each be valuable on their own:

- **Sharpen** — the product-challenge protocol (Stage 1)
- **Create-worktree** — the worktree bootstrapper (`create-worktree.sh`)
- **UX Advisor** — the full UX critique protocol (Stage 4.4.1)
- **Code review** — the second-opinion `codex` wrapper (Stage 4.6)
- **Automated-review fix** — the Greptile/CodeRabbit comment-resolution loop (Stage 7)

Each inlined section is marked with an `INLINED:` HTML comment block in `SKILL.md` calling out the extraction opportunity. If you maintain your own plugin marketplace and want to reuse these protocols outside fab, extracting them into standalone skills is straightforward — the inlined sections are deliberately faithful copies, not lossy summaries.

## License

[MIT](LICENSE) © 2026 Headline VC.

## Credits

Fab was built by [Headline](https://headline.com/) for our internal engineering team and open-sourced for general use. The Headline-internal version composes additional private skills (deeper observability integrations, custom team-routing, and product-specific advisors); the public version inlines a generalized form of those that works on any stack.
