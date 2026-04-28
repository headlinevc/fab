# fab

A skill for [Claude Code](https://claude.com/claude-code) that takes a feature idea and ships it.

```
/fab
```
> "Add a CSV export button to the customers table"

You'll get pushback first — is CSV export the actual problem, or is it data portability? Once a direction is locked, fab writes a spec, sets up an isolated worktree, has a Staff Engineer agent build it, runs a panel of advisor agents (UX, API, security, whatever the surface needs), runs standard and adversarial code reviews, takes screenshots, and hands you a running localhost. You say "ship it"; it pushes, opens a PR, fixes CI, resolves automated-review comments, audits docs, and posts a retro.

You're in the loop four times: challenge the framing, approve the spec, test the build, land the PR. That's it.

## Inspired by, and what we did differently

Three projects shaped how we thought about fab. Each is worth reading on its own terms.

- [**gstack**](https://github.com/garrytan/gstack) — Garry Tan's roster of slash-command roles (CEO, eng manager, designer, reviewer, QA, security, release engineer) for shipping features through Claude Code. Its [`ETHOS.md`](https://github.com/garrytan/gstack/blob/main/ETHOS.md) makes the case for "User Sovereignty" as a stated principle — *"AI models recommend. Users decide... Never act."* In practice the shape varies by command (autoplan is fairly autonomous with two gates; office-hours and design-consultation pause through wireframe review). gstack is where we got the idea that turning agents into specialists with strong POVs beats turning them into generalists.

- [**gastown**](https://github.com/gastownhall/gastown) — Steve Yegge's multi-agent orchestration system (Mayor coordinator + Polecat workers + Beads ledger for persistent work state). Different category from fab — it's the *runtime* you'd coordinate many agents on, not a feature-shipping workflow. We borrowed the idea that work state must live outside the agent's memory in a file the next agent can read. fab's `.fab` pipeline-state file is the budget version of that idea.

- [**superpowers**](https://github.com/obra/superpowers) — Jesse Vincent's composable skills library and 7-step workflow (brainstorm → worktree → plan → subagent execution → TDD → review → finish). Closest precedent to fab in shape: a few human touchpoints (validate design, approve plan, "say go", choose merge/PR/keep/discard) and long autonomous stretches in between. The "fresh subagent per task with two-stage review" pattern is one we carried forward into Stage 4.

We're not faster on touchpoint count — superpowers gets there too. What fab does that we couldn't get from any of these three:

1. **Gate-enforced pipeline.** A `PreToolUse` hook (`fab-gate.sh`) physically blocks `git commit` until both standard and adversarial code reviews are recorded in `.fab`, and blocks `gh pr create` until a commit hash is recorded. The discipline lives in the hook, not in prompt instructions an agent could rationalize past. None of the three inspirations gate via `PreToolUse` — superpowers' hook config is `SessionStart`-only, gstack ships none.

2. **Adversarial review as a separate stage, not a code-review checkbox.** Stage 4.6 hunts bugs; Stage 4.7 questions the design itself — *"should you have built it this way at all?"* Two distinct sub-agent passes with different prompts. They find different things.

3. **Advisors with stated points of view that don't overlap.** Each advisor (UX, API, Security, Performance, Brand Voice, Product, Taste) has a one-paragraph POV defining what they own and what they explicitly don't. UX owns *easy*. Product owns *valuable*. Taste owns *joyful*. Findings in someone else's domain go to that advisor. Stops the "everyone reviews everything and agrees with each other" pile-on.

4. **The ux-advisor skill as a working example of advisor depth.** It's 586 lines on its own — a 14-step critique protocol with a worked example, full reference library, and explicit anti-patterns. Ships in this same plugin and runs both as fab Stage 2.5 (pre-flight on the spec) and as `/ux-advisor` standalone. The point is to demonstrate what an advisor looks like when you stop treating it as a generic role and start treating it as a tool.

The four human touchpoints we kept — challenge framing, approve spec, test build, land PR — are the places we couldn't talk ourselves into letting an agent decide. Everything else, an agent decides faster than a human can answer the question.

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

[MIT](LICENSE) © 2026 Headline Services US, LLC.

## Credits

Built at [Headline](https://headline.com/) for our internal engineering team. The version we run internally composes a few additional private skills — deeper observability hooks, team-specific routing, and product-specific advisors — none of which would mean anything outside our codebase. The public version drops those and ships a generalized form that works on any stack.

Bug reports and PRs welcome. We're not promising support, but we use this every day, so it'll keep moving.
