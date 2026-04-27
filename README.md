# fab

A skill for [Claude Code](https://claude.com/claude-code) that takes a feature idea and ships it.

```
/fab
```
> "Add a CSV export button to the customers table"

You'll get pushback first — is CSV export the actual problem, or is it data portability? Once a direction is locked, fab writes a spec, sets up an isolated worktree, has a Staff Engineer agent build it, runs a panel of advisor agents (UX, API, security, whatever the surface needs), runs standard and adversarial code reviews, takes screenshots, and hands you a running localhost. You say "ship it"; it pushes, opens a PR, fixes CI, resolves automated-review comments, audits docs, and posts a retro.

You're in the loop four times: challenge the framing, approve the spec, test the build, land the PR. That's it.

## Inspired by, but built differently

fab borrows ideas from three projects worth reading on their own:

- [**gstack**](https://github.com/garrytan/gstack) — Garry Tan's stack of agent commands for shipping features.
- [**gastown**](https://github.com/gastownhall/gastown) — Steve Yegge's exploration of LLM-orchestrated dev workflows.
- [**superpowers**](https://github.com/obra/superpowers) — obra's library of skill primitives.

What we wanted that none of them gave us: **minimal human-in-the-loop**. Each of those projects pauses to check in with you a lot — confirm this, review that, pick from these options, approve before continuing. That's safe but it's slow, and it shifts the cognitive load back to you exactly when you wanted to offload it.

fab pauses at four points and four points only. They're the places where human judgment changes the outcome:

1. **Challenge** — is this the right thing to build?
2. **Approve** — is this the right spec to build it from?
3. **Test** — did the running thing actually solve the problem?
4. **Land** *(optional)* — merge now or later?

Outside those four, fab doesn't ask. It picks advisors based on what the change touches, decides which patterns to follow, fixes its own CI failures, judges which automated-review comments to act on and which to dismiss, and audits its own docs. If it's wrong about something, you'll catch it at the next touchpoint and redirect. If it's not wrong, you saved an hour of micro-decisions that an agent should have made on its own.

The hard gates aren't human approvals. They're a pre-tool-call hook (`fab-gate.sh`) that physically blocks `git commit` until standard + adversarial code reviews have run, and blocks `gh pr create` until a commit exists. You can't accidentally skip them. The agent can't either.

## Install

This repo is a Claude Code plugin with two skills: **fab** (the orchestrator) and **ux-advisor** (a deep UX critique protocol fab composes during pre-flight and review).

### As a plugin (recommended)

Add this repo as a marketplace and install:

```
/plugin marketplace add headlinevc/fab
/plugin install fab@fab
```

Then restart Claude Code. `/fab` and `/ux-advisor` will both appear.

### Manually

```bash
git clone https://github.com/headlinevc/fab.git ~/code/fab
ln -s ~/code/fab/skills/fab ~/.claude/skills/fab
ln -s ~/code/fab/skills/ux-advisor ~/.claude/skills/ux-advisor
```

### Activate the pipeline-gate hook

The hook enforces fab's commit/PR ordering. fab installs the script on first run, but you need to register it in `~/.claude/settings.json`:

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

The hook is silent unless a `.fab` file is in the working directory, so it doesn't interfere with anything outside fab worktrees.

## Configuration

fab reads project conventions from your repo's `CLAUDE.md`. Set these once and fab stops asking:

```markdown
Default team: ABC                    # ticket-tracker team or project key
Audience: <one sentence>             # who uses this product (shapes UX/voice critique)
Stack: rails+react                   # optional; otherwise auto-detected from lockfiles
Ticket tracker: linear | github | none
```

If a value's missing, fab auto-detects when it can (stack from `Gemfile`/`package.json`/`pyproject.toml`/etc., tracker from which CLI is authed) and asks once if it can't.

## What you need

Hard requirements:

- `git`
- [Claude Code](https://claude.com/claude-code)

Strongly recommended:

- [`codex`](https://github.com/openai/codex) CLI — for the second-opinion code reviews in Stage 4.6 and 4.7. fab will refuse to commit without it unless you explicitly skip those stages.
- [`gh`](https://cli.github.com/) — for PR creation and automated-review handling.
- A browser automation tool (Playwright, Puppeteer, headless Chrome) — for the visual QA pass in Stage 4.9. Skipped if absent.

Optional:

- [`linear`](https://linear.app/) CLI — if you use Linear as your tracker. Otherwise fab uses GitHub Issues, or a local markdown spec at `.fab/specs/{id}.md`.
- `overmind` + a `Procfile.dev` — if your repo runs multiple dev servers in parallel and assigns slots.

## The two skills

**`fab`** ([SKILL.md](skills/fab/SKILL.md)) — the orchestrator. 9 stages, 4 touchpoints. Reads project config, dispatches sub-agents, enforces the pipeline gates.

**`ux-advisor`** ([SKILL.md](skills/ux-advisor/SKILL.md)) — a senior UX advisor with opinions about your screens. It runs a 14-step critique protocol covering first-fixation reasoning, mental-model formation, mental-math audits, Jakob's Law conformance, cognitive bias, accessibility, AI-slop detection, copy craft, and ranked simplification. It's invoked twice during a fab run (pre-flight on the spec, post-review on the build), and it's also useful on its own — point it at any screen and it'll critique.

ux-advisor is the example of how an advisor can be turned into something serious. fab inlines compressed versions of several other advisor protocols (Product, Taste, API, Security, Performance, Brand Voice) directly in its SKILL.md; if any of those grow to ux-advisor scale, the same extraction pattern applies.

## How fab is built

fab orchestrates 9 stages, with the four human touchpoints at stages 1, 3, 6, and (optional) post-7.

| Stage | Who | What |
|-------|-----|------|
| 0 | auto | Bootstrap the fab-gate hook |
| 1 | **you** | Product challenge — pressure-test the idea |
| 2 | auto | Spec — write tracker entry, assemble advisor team |
| 3 | **you** | Approve spec |
| 4 | auto | Worktree, Staff Engineer, advisors, code reviews, visual QA |
| 5 | auto | Notify with screenshots |
| 6 | **you** | Test, give feedback |
| 7 | auto | Ship — PR, CI, automated-review fixes |
| 8 | auto | Doc audit |
| 9 | auto | Retro |

Stages 4.6 and 4.7 (standard + adversarial code review) and the commit are gate-enforced. fab can't skip them. The hook reads `.fab` and refuses `git commit` until both reviews are recorded as done; refuses `gh pr create` until a commit hash is recorded.

## License

[MIT](LICENSE) © 2026 Headline VC.

## Credits

Built at [Headline](https://headline.com/) for our internal engineering team. The version we run internally composes a few additional private skills — deeper observability hooks, team-specific routing, and product-specific advisors — none of which would mean anything outside our codebase. The public version drops those and ships a generalized form that works on any stack.

Bug reports and PRs welcome. We're not promising support, but we use this every day, so it'll keep moving.
