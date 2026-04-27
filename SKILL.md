---
name: fab
description: |
  End-to-end feature fabrication: idea to testable implementation with four human touchpoints.
  Challenges the user's product framing before building, creates a spec, sets up an isolated
  worktree, implements with adversarial review and visual QA, delivers a running local
  instance with screenshots, and handles post-ship doc audit and retro.
  Use when the user wants to build a feature hands-off, or says "fab", "fabricate", or
  "build this end to end".
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Skill
  - AskUserQuestion
---

# Fab: End-to-End Feature Fabrication

Take a rough idea, challenge it into the right product, and fabricate it into a testable, running feature with minimal human input.

## Usage
```
/fab
```
Then describe what you want. The skill handles everything from spec to running code.

## Four Human Touchpoints

| # | When | What you do | Everything else is autonomous |
|---|------|-------------|-------------------------------|
| 1 | **Challenge** | Describe what you want. Claude pushes back on framing, challenges premises, proposes alternatives. You pick a direction. | Codebase investigation, product analysis, alternative generation |
| 2 | **Approve** | Review the spec summary. Say "go" or give feedback. | Spec writing, ticket creation, worktree setup, implementation, testing, visual QA, adversarial review, dev server startup |
| 3 | **Test** | Click around on localhost (with screenshots already provided). Give feedback or say "ship it." | Bug fixes from feedback, commit, push, PR creation, CI fixes, automated review fixes, doc audit, retro |
| 4 | **Land** *(optional)* | Say "land it" to merge, or merge yourself. | Merges PR, updates ticket status to Done |

---

## Project conventions fab reads

Fab tries to be portable across stacks and trackers. Where it has a choice, it reads project context from the repo's `CLAUDE.md` (or asks if missing). Add any of these lines to keep fab autonomous:

```markdown
# CLAUDE.md

Default team: ABC                   # ticket-tracker team code or project key
Audience: <one sentence>            # who uses this product, e.g. "external API consumers"
Stack: rails+react                  # optional override; otherwise auto-detected
Worktree pattern: ~/dev/<slug>      # where worktrees should live
Ticket tracker: linear | github | none
```

If a value is missing, fab will auto-detect when possible (stack, tracker) or ask once via `AskUserQuestion`.

---

## Stage 0: Bootstrap (silent, automatic)

**Before anything else**, verify the fab-gate hook is installed. This hook enforces pipeline gates — without it, `git commit` and `gh pr create` can bypass required stages.

Run this check silently at the start of every `/fab` invocation:

```bash
# Check if fab-gate hook is installed
if ! grep -q 'fab-gate' ~/.claude/settings.json 2>/dev/null; then
  echo "Installing fab-gate hook..."

  # Find the hook script — first in the plugin cache, then alongside this skill.
  HOOK_SRC=$(find ~/.claude/plugins/cache -path "*/fab/*/hooks/fab-gate.sh" -type f 2>/dev/null | sort -V | tail -1)

  if [ -z "$HOOK_SRC" ] && [ -n "$FAB_BASE" ]; then
    HOOK_SRC="$FAB_BASE/hooks/fab-gate.sh"
  fi

  if [ -n "$HOOK_SRC" ] && [ -f "$HOOK_SRC" ]; then
    mkdir -p ~/.claude/hooks
    cp "$HOOK_SRC" ~/.claude/hooks/fab-gate.sh
    chmod +x ~/.claude/hooks/fab-gate.sh
    echo "Copied fab-gate.sh to ~/.claude/hooks/"
  fi
fi
```

If the bootstrap detects the hook is missing, it installs the script and tells the user to activate it.

After bootstrap, check for `fab-gate` in `~/.claude/settings.json`. If the hook config is missing, use the Edit tool to add it:

```json
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
```

Then proceed to Stage 1.

---

## Stage 1: Product Challenge (YOU + Claude)

**Goal:** Make sure we're building the right thing before we build it well. The most expensive mistake is building the wrong feature perfectly.

<!-- ━━━ INLINED: SHARPEN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     The product-challenge protocol below is inlined from a separate "sharpen" skill.

     OPPORTUNITY: This is a substantial body of product-thinking expertise that
     deserves its own skill. If you maintain a Claude Code plugin marketplace,
     consider extracting Stage 1 into a standalone `sharpen` skill that fab
     can compose via the Skill tool. Benefits: usable as `/sharpen` outside fab,
     can grow its own council/canon files independently, easier to evolve voice
     rules without touching the rest of fab.
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->

### 1.1 Voice rules

You are a sparring partner, not a yes-man. Be direct, concrete, and sharp.

**Never say:** "That's interesting" / "There are many ways to think about this" / "You might want to consider" / "That could work" / "Great question". State your actual position: "This won't work because..." / "This is solid because..." / "The real problem here is...".

If the idea is good, say why with specifics. If it has problems, name them. Vague encouragement is the opposite of sharpening.

### 1.2 Listen

Let the user describe what they're thinking. Don't interrupt. Wait until they stop.

### 1.3 Investigate (silent)

Before responding, gather context relevant to what they described:

- Find the relevant files, components, and patterns
- Check if similar features exist that could serve as **pattern anchors** — note specific `file:line` references
- Identify potential conflicts or **architectural concerns**
- **Look for existing code that already partially solves the problem** — the user may not know it exists
- **Check how users currently work around the gap** — workarounds reveal the real need

### 1.4 Reframe

State what the user *actually* described, which may differ from what they asked for. People often request a specific solution when they're describing a broader problem.

> Example: "You said 'add a CSV export button.' What you described is that your users can't get data out of the system to share with their team. CSV is one solution — the real problem is data portability."

If the user's framing is accurate and specific, say so and move on. Don't manufacture pushback.

### 1.5 Challenge through conversation

This is not a survey. Pick the **2–3 sharpest questions** for this idea, drawn from these forcing patterns. Ask 1–2 at a time, wait for the answer, follow up.

**Demand & specificity:**
- Who exactly feels this pain? Push for a name, role, specific consequence.
- What's the strongest evidence someone actually wants this? Push for behavior — money spent, time invested, workarounds built.
- What are they doing right now instead? The status quo is the real competitor.

**Scope & ambition:**
- What's the smallest version someone would actually use?
- What would the 10x version look like? Even if you build the 1x, knowing the 10x shapes architecture today.
- What happens if we don't do this at all?

**Durability:**
- If the world looks different in 2 years, does this become more essential or less?
- What already exists that partially solves this? Reference specific code from the investigation.

If the user gives a vague answer, push back: "That's abstract. Give me a specific example." If they give a strong answer, say so and move on.

### 1.6 Propose alternatives

Based on the investigation and conversation, propose **2–3 approaches** with tradeoffs:

```
Approach A: [Narrowest wedge — ship today]
  Effort: ~X minutes | Scope: Y files | Risk: low
  Tradeoff: [what you give up]

Approach B: [Balanced — covers the core need]
  Effort: ~X minutes | Scope: Y files | Risk: medium
  Tradeoff: [what you give up]

Approach C: [Full vision — the 10x version]
  Effort: ~X minutes | Scope: Y files | Risk: higher
  Tradeoff: [what you give up]

Recommendation: [Pick one and explain why in 1-2 sentences]
```

If there's only one reasonable approach, say so. Don't invent alternatives for the sake of it.

### 1.7 Lock direction

Wait for the user to pick. They may pick as-is, combine, reject and reframe (return to 1.4), say "just do what I said" (respect that — they've heard the pushback), or keep sparring.

Do NOT proceed to Stage 2 until a direction is locked.

### 1.8 Hand-off summary

When direction is locked, write a structured summary that Stage 2 will consume:

```
Direction locked:
  Approach: [which one, or synthesis]
  Core problem: [reframed problem statement]
  Key decisions: [2-3 bullets of what was decided]
  Pattern anchors: [file:line references for implementation]
  Out of scope: [what was deferred or rejected]
```

---

## Stage 2: Spec (autonomous)

**Goal:** Create a comprehensive spec — either a ticket in your tracker or a markdown file at `./.fab/specs/{ticket-id}.md`.

### 2.0 Scope review

Classify the scope of what the user approved in Stage 1:

| Mode | When | What it means |
|------|------|---------------|
| **Reduce** | Ask is too ambitious for one PR | Cut to MVP. Identify what to defer; create follow-up tickets. |
| **Hold** | Scope is right-sized | Refine execution, don't expand. |
| **Refine** | Good direction, missing something | Add the missing piece without bloating scope. |
| **Expand** | User is thinking too small | The 10x version is within reach — propose it, only if effort is marginal. |

Apply scope-forcing checks:
1. **What already exists?** Don't rebuild what's there (use the pattern anchors from 1.3).
2. **Complexity smell** — if the approach touches 8+ files or introduces 2+ new classes/services, it's probably too big for one fab. Split it.
3. **Completeness check** — AI-assisted coding makes 100% completeness cheap. Don't leave half-done edges, empty states, or missing error handling "for later."

State the scope mode and your reasoning in 1–2 sentences, then proceed.

### 2.1 Detect ticket tracker

Decide where the spec lives:

```bash
# Order of preference: explicit override → linear → github → local file
TRACKER=$(grep -oE '^Ticket tracker:[[:space:]]+[a-z]+' CLAUDE.md 2>/dev/null | awk '{print $NF}')

if [ -z "$TRACKER" ]; then
  if command -v linear >/dev/null && linear whoami >/dev/null 2>&1; then
    TRACKER=linear
  elif command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    TRACKER=github
  else
    TRACKER=none
  fi
fi
```

Read team / project key from `CLAUDE.md`:
```bash
DEFAULT_TEAM=$(grep -oE 'Default team:[[:space:]]+[A-Z0-9]+' CLAUDE.md 2>/dev/null | awk '{print $NF}')
```
If `DEFAULT_TEAM` is empty and `TRACKER=linear`, ask the user once via `AskUserQuestion` ("Which Linear team should I use? (e.g. ABC)") before proceeding.

### 2.2 Write the spec

Write a comprehensive spec covering:

1. **Discovery** — context from Stage 1.3, deepened as needed (observability data for bugs, architectural analysis for features).
2. **EARS requirements** — every requirement in EARS format (Event/Action/Response/State). Include Agent Stories with file:line pattern references.
3. **Non-goals** — preserved behaviors as positive statements ("X continues to do Y").
4. **Context anchors** — pattern-to-follow references with specific file:line.
5. **Solution approach** — pick the recommended approach. Don't present alternatives unless genuinely close.
6. **Task decomposition** — phases with `[P]`/`[S]`/`[B]` parallel/sequential/blocking markers. Target 5–15 min per phase.
7. **Visual verification** — automated browser-test spec if UI-observable.
8. **Implementation team** — table of advisors selected in 2.4.
9. **Success criteria** — what "done" looks like.
10. **Risk assessment** — what could go wrong; mitigations.

### 2.3 Create the ticket / spec file

Write the full spec markdown to `/tmp/fab-ticket-desc.md` first, then create the tracker entry from it:

**Linear:**
```bash
linear issue create \
  --team "$DEFAULT_TEAM" \
  --title "[Type]: [Title]" \
  --description-file /tmp/fab-ticket-desc.md \
  --priority 3 \
  --state "In Progress" \
  --assignee self \
  --no-interactive
# Parse the ticket ID (e.g., ABC-1234) from the CLI output.
```

**GitHub Issues:**
```bash
gh issue create --title "[Type]: [Title]" --body-file /tmp/fab-ticket-desc.md
# The output is a URL ending in /issues/N — use that N as the ticket ID (e.g. "issue-N").
```

**No tracker (local spec):**
```bash
SLUG=$(echo "$TITLE" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9-]//g' | head -c 40)
TICKET_ID="spec-$(date +%Y%m%d)-$SLUG"
mkdir -p .fab/specs
cp /tmp/fab-ticket-desc.md ".fab/specs/$TICKET_ID.md"
```

Record `TICKET_ID` for later stages. Clean up `/tmp/fab-ticket-desc.md` once written.

### 2.4 Assemble the team

After creating the spec, decide what advisory expertise the staff engineer needs. Core principle: **one agent codes, everyone else provides expert guidance.**

Add an **Implementation Team** section to the spec (between Success Criteria and Risk Assessment):

```markdown
## Implementation Team

| Role | Responsibility | Point of View |
|------|---------------|---------------|
| **Staff Engineer** | Builds full-stack, owns all code. The only agent who writes code. | Senior full-stack developer handling backend, frontend, database, and tests. |
| **[Advisor Name]** | Reviews [domain], does not write code. | "[Their POV statement]" |
| ... | ... | ... |

**Strategy:** Sub-agents (sequential review) | Agent team (real-time guidance)
```

Update the spec via your tracker's update command (e.g. `linear issue update`, `gh issue edit --body-file`, or a re-write of the local spec file).

#### The Staff Engineer (always present)

Every fab has exactly one Staff Engineer — a senior full-stack developer who writes ALL the code. They work alone in the worktree. **Nobody else writes code.** This prevents merge conflicts, inconsistent patterns, and agents stepping on each other.

#### Advisory roster

Each advisor has a **point of view** — a strong opinion about what good looks like in their domain. Advisors don't write code; they review, challenge, and guide.

| Project signal | Advisor | Their POV |
|----------------|---------|-----------|
| UI components, layouts, user flows | **UX Advisor** | "I own *easy*. I critique through first-fixation, mental model mapping, split-attention, Jakob's Law against the right reference set, cognitive bias, and AI slop detection. I don't own memorability (→ Taste) or whether we're solving the right problem (→ Product) — I own whether a human can drive the UI without having to ask *how*." |
| API endpoints, data contracts, integrations | **API Advisor** | "APIs are promises. Every endpoint must have a clear contract, proper error responses, and versioning awareness. I catch breaking changes before they ship." |
| User-facing copy, audience-sensitive surfaces | **Brand Voice Advisor** | "Every label, tooltip, and empty state must communicate competence and clarity to *this product's audience* (read `Audience:` in CLAUDE.md). No jargon without purpose. No ambiguity." |
| Database queries, performance-sensitive paths | **Performance Advisor** | "I think in N+1 queries and unnecessary re-renders. If it touches a database or triggers a network request, I want to know why and how often." |
| Auth, permissions, data exposure | **Security Advisor** | "I assume every input is hostile and every endpoint is public. I enumerate the attack surface, check auth boundaries, scan for secrets and injection vectors, and only report findings at 8/10+ confidence — false positives erode trust." |
| Complex business logic, multi-step workflows | **Product Advisor** | "I own *valuable*. Am I building a solution dressed up as an opportunity, or the real thing a user does moment-to-moment? Does the flow match how the user actually works, including the workflow edges the spec forgot? Will this change a user behavior, or ship silently into the forest?" |
| Net-new user-facing UI; first-impression features | **Taste Advisor** | "I own *joyful*. Where did we leave a config surface instead of deciding? Does this feel like one mind or a committee? What's the one sentence that'd be *wrong* to say about the alternative? If this shipped beside a competitor's, could anyone tell which one was ours?" |

#### Custom advisors

The roster above is a starting set, not a closed list. If the project touches a domain not covered, **create a custom advisor on the fly.** Requirements:

1. **A clear domain** — what area of expertise they own.
2. **A strong POV statement** — one opinionated paragraph about what good looks like. Should feel like a real person who cares deeply about this one thing.
3. **Domain-specific review instructions** — what specifically they look at in the code.

Examples: Email Deliverability, Search/Relevance, Data Pipeline reliability, Accessibility, Internationalization, Mobile/Responsive, Observability/Telemetry.

#### Selection rules

The three UI-adjacent advisors own distinct questions. If an advisor's finding could be written by a different advisor, it belongs to the other one — don't let them overlap.

| Advisor | Owns the question |
|---|---|
| **Product Advisor** | Is the right thing being built for the right person? |
| **UX Advisor** | Can a human drive this without training? |
| **Taste Advisor** | Would anyone remember we built this? |

- **UX Advisor** — default for nearly every UI-touching feature.
- **Product Advisor** — add when the feature has a real user workflow with stakes.
- **Taste Advisor** — add for net-new user-facing UI or first-impression surfaces.
- **API-heavy work:** **API Advisor** is mandatory.
- **Max 3 advisors.** More creates noise, not signal.
- **Simple bug fixes / small changes:** skip advisors entirely.

#### How advisors work

**With sub-agents (sequential, default):**
1. Staff Engineer implements the full spec.
2. Each advisor reviews from their POV (dispatched as separate sub-agents, can run in parallel).
3. Staff Engineer receives combined feedback and fixes.
4. Advisors re-review until satisfied.

**With agent teams (concurrent):** advisors observe via a shared `.fab` state file and can message the Staff Engineer mid-implementation. Use this only when the feature is complex enough that real-time guidance pays off.

### 2.5 UX pre-flight (if UX Advisor is on the team)

If the team includes a UX Advisor, run a pre-flight critique on the spec **before implementation begins**. Design-level problems caught here cost nothing to fix; the same problems caught in 4.3 cost a full implementation cycle.

Use the inlined UX critique protocol in §4.3.1 below. Frame the input as: "Here is the spec for a feature we are about to build. Critique the proposed interaction model and information hierarchy before implementation." Provide the audience (from `Audience:` in CLAUDE.md), the key UI surfaces from the EARS requirements, and the solution approach.

If pre-flight finds Critical or Important issues, revise the spec before Stage 3 and update the tracker entry. Surface findings in the Stage 3 checkpoint summary so the user sees the design has been challenged before they approve.

---

## Stage 3: Checkpoint (YOU approve)

**Goal:** Get the user's go/no-go before autonomous work begins.

```
Ticket: {TICKET_ID} — [Title]
URL/Path: [tracker URL or .fab/specs/{ticket-id}.md]

Summary: [2-3 sentences of what will be built]

Scope: [X] phases, [Y] tasks ([Z] parallelizable)
Estimated effort: [X] minutes of agent work

Team:
  Staff Engineer — builds full-stack, owns all code
  [Advisor 1 name] — [their one-line POV]
  [Advisor 2 name] — [their one-line POV]
  Strategy: sub-agents (sequential) | agent team (real-time)

UX pre-flight: [Clean / N findings addressed in spec — or "N/A, no UX Advisor"]

Ready to fabricate?
```

**Wait for user response.** "go"/"yes"/"do it" → Stage 4. Feedback on spec → update tracker entry, re-present. Feedback on team → adjust advisors, re-present. "stop"/"cancel" → abort.

---

## Stage 4: Implementation (autonomous)

**Goal:** Create worktree, implement everything with advisory guidance, deliver a running local instance.

### 4.0 Initialize pipeline state (MANDATORY FIRST STEP)

After creating the worktree and `cd`'ing in, initialize the `.fab` state file. This file is the **enforcement mechanism** — the fab-gate hook blocks `git commit` and `gh pr create` unless required pipeline stages are recorded.

```bash
# FAB_BASE = the "Base directory for this skill" shown in system context
bash "$FAB_BASE/fab-init.sh" "$PWD" "{TICKET_ID}"
```

The script writes `ticket=` and `fabricated_at=` lines, gitignores `.fab` locally (via `.git/info/exclude`), is idempotent, and fails loudly outside a git worktree.

Each pipeline stage appends one line to `.fab` when done:

| Stage | Line appended | What it unlocks |
|-------|--------------|-----------------|
| Implementation done | `implementation=done` | Advisory review can start |
| Advisory review done | `advisory=done` | Standard review can start |
| Standard code review done | `codex_standard=done` | Adversarial review can start |
| Adversarial review done | `codex_adversarial=done` | **`git commit` unblocked** |
| Changes committed | `committed={short-sha}` | **`gh pr create` unblocked** |
| PR created | `pr={number}` | Greptile, doc audit, retro can start |
| Automated review fix done | `greptile=done` | — |
| Doc audit done | `doc_audit=done` | — |
| Retro done | `retro=done` | Pipeline complete |

To record a stage: `echo "stage_name=done" >> .fab`. To check state: `cat .fab`.

### 4.1 Create worktree

**Every fab MUST use a worktree.** No exceptions. Don't `git checkout -b` in the user's main checkout, and don't use the Agent tool's `isolation: "worktree"` for this — that's for ephemeral exploration, not for a deliverable the user will test.

<!-- ━━━ INLINED: CREATE-WORKTREE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Worktree creation is delegated to a sibling shell script (`create-worktree.sh`).
     The script auto-detects yarn/npm/pnpm, copies .env files, fixes submodule
     gitlinks for `.claude/`, and assigns dev slots when Procfile.dev is present.

     OPPORTUNITY: This is mature, repo-portable shell code that other agents
     and skills could reuse. Consider extracting it into a standalone
     `create-worktree` skill (with team-orchestration logic for spinning up
     parallel agents on sub-issues — fab uses single-worktree mode but the
     script supports both). Kept here so fab needs no plugin dependencies.
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->

```bash
# FAB_BASE = the "Base directory for this skill" from system context
bash "$FAB_BASE/create-worktree.sh" "feature/{TICKET_ID}-{slug}" "{TICKET_ID}-{short-desc}"
```

Worktree directory names are capped at 40 chars when the repo uses overmind (Procfile.dev) — overmind's tmux Unix sockets exceed macOS's path-length limit otherwise. The script enforces this and exits with a clear error.

**Record the worktree path and dev slot port** — you'll need both.

**Immediately `cd` into the worktree and stay there for the rest of fab.** The Bash tool's working directory persists across calls, so this single `cd` is what makes every subsequent command run inside the worktree:

```bash
cd ~/dev/{worktree-name} && pwd
```

Do NOT use one-shot `cd ... && ...` patterns later — you've already cd'd. When fab finishes, the user's session is left inside the worktree, which is what they want.

If worktree creation fails, STOP and report. Do NOT fall back to working in the main repo.

**Now initialize `.fab`** by running `fab-init.sh` (see §4.0). This MUST happen before any implementation work.

```bash
bash "$FAB_BASE/fab-init.sh" "$PWD" "{TICKET_ID}"
```

### 4.2 Detect stack

Read the stack hint from `CLAUDE.md` if present, else auto-detect. This determines which test/lint commands the Staff Engineer should run.

```bash
STACK=$(grep -oE '^Stack:[[:space:]]+\S+' CLAUDE.md 2>/dev/null | awk '{print $NF}')

if [ -z "$STACK" ]; then
  STACK=""
  [ -f Gemfile ] && STACK="${STACK}+ruby"
  [ -f package.json ] && STACK="${STACK}+node"
  [ -f pyproject.toml ] || [ -f requirements.txt ] && STACK="${STACK}+python"
  [ -f Cargo.toml ] && STACK="${STACK}+rust"
  [ -f go.mod ] && STACK="${STACK}+go"
  STACK="${STACK#+}"
fi
```

Map stack hints to commands the Staff Engineer should run:

| Stack | Test | Lint/Type | Dev server |
|-------|------|-----------|-----------|
| `ruby` (Rails) | `bundle exec rails test` or `bundle exec rspec` | `bundle exec rubocop` | `bin/dev` if present, else `bundle exec rails server` |
| `node` | `npm test` or `yarn test` or `pnpm test` | `npx tsc --noEmit` if `tsconfig.json` else `npm run lint` | `npm run dev` or `bin/dev` if present |
| `python` | `pytest` | `ruff check` if config present, else `python -m mypy .` | `python manage.py runserver` if Django, else project-specific |
| `rust` | `cargo test` | `cargo clippy -- -D warnings` | `cargo run` |
| `go` | `go test ./...` | `go vet ./...` (+ `golangci-lint run` if installed) | `go run .` |

If the stack is unrecognized or the dev server isn't obvious, ask the user once via `AskUserQuestion`.

### 4.3 Dispatch Staff Engineer

Spawn the developer agent:

```
Agent tool:
  subagent_type: "general-purpose"
  description: "Implement {TICKET_ID}"
  prompt: |
    You are the Staff Engineer implementing {TICKET_ID}: {title}

    You are the ONLY agent who writes code. You are a senior full-stack developer
    who handles backend, frontend, database, and tests.

    ## Your workspace
    Work EXCLUSIVELY in: ~/dev/{worktree-name}

    ## Your spec
    {if linear: linear issue view {TICKET_ID} --no-pager}
    {if github: gh issue view {TICKET_ID} --comments}
    {if local: cat .fab/specs/{TICKET_ID}.md}

    The spec contains EARS requirements, context anchors, task decomposition,
    and visual verification spec. Follow the implementation phases in order.

    ## Your advisory team
    After you finish, your work will be reviewed by:
    {for each advisor: "- [Name]: [Their POV statement]"}

    Keep their perspectives in mind as you build.

    ## Implementation rules
    - Follow the task decomposition phases exactly as specified
    - Use the context anchors — follow existing patterns, don't invent new ones
    - Implement ONLY what the spec says. No extras. No "nice to haves."
    - If something is unclear, check the Non-Goals section before assuming
    - Run tests after each phase: {STACK_TEST_COMMANDS}

    ## Testing (mandatory — you cannot report DONE without tests)

    After implementation, you MUST write tests for every new behavior. This is
    a hard gate. No tests = not done.

    1. Follow the spec's Testing phase.
    2. Tests for new behavior:
       - Use hardcoded expected values, not computed ones
       - Follow existing test patterns in the codebase
    3. What to test:
       - Every EARS requirement should have at least one test
       - Error/edge cases from the spec's "Unwanted" and "State-driven" requirements
       - API contracts: request/response shapes, status codes, error formats
       - Do NOT write trivial tests that just assert the component renders
    4. What NOT to test:
       - Pre-existing behavior you didn't change
       - Third-party library behavior
       - Implementation internals

    ## Verification

    After writing tests, run the full suite for {STACK}:
    {STACK_TEST_COMMANDS}

    Fix any failures. All tests must pass.

    Stage all changes: git add [specific files]
    Do NOT commit yet — review steps come first.

    ## Self-review

    Before reporting completion, review your own work:
    - Did you implement everything in the EARS requirements?
    - Did you write tests for every new behavior?
    - Did you violate any Non-Goals?
    - Did you follow the context anchor patterns?
    - Did you add anything not in the spec?
    - Do all tests pass?

    ## Report format
    When done, report:
    - Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
    - Files changed (list them)
    - Tests written (list them with what they verify)
    - Test results (passing / failures)
    - Any concerns or deviations from spec
```

When the Staff Engineer reports DONE, record it: `echo "implementation=done" >> .fab`.

### 4.3.5 Start dev server (early)

Start the dev server immediately, before advisory review, so any UI advisor has rendered output to reason about during their review.

Run the dev-server command from §4.2's stack table, in the background. Wait for the server to be ready (look for "Listening on", "ready", or equivalent in logs). The port is the dev slot assigned during worktree creation, if applicable.

If the dev server fails to start, proceed code-only — log the failure but don't block.

### 4.4 Advisory review

Dispatch each advisor as a sub-agent. Advisors run in parallel; they don't write code, they only read and critique.

For each advisor:

```
Agent tool:
  subagent_type: "general-purpose"
  description: "{Advisor name} review {TICKET_ID}"
  prompt: |
    You are the {Advisor Name} reviewing implementation of {TICKET_ID}.

    ## Your identity
    {Advisor's full POV statement}

    You have a STRONG OPINION about what good looks like in your domain.
    You are not here to rubber-stamp. You are here to catch what the developer
    missed because they were focused on making it work, not making it right
    from your perspective.

    ## Workspace
    Review code in: ~/dev/{worktree-name}

    ## The spec
    {appropriate command for the active tracker}

    ## Your review approach
    {Domain-specific review instructions — see roster guidance below}

    ## What NOT to flag
    - Things outside your domain
    - Style nits or naming preferences
    - Pre-existing issues not introduced by this change

    ## Report format
    For each finding:
    - Severity: Critical | Important | Suggestion
    - Location: file:line
    - What's wrong from YOUR perspective (1–2 sentences)
    - What should change (1–2 sentences)

    If no real issues in your domain: "No findings from [your domain] perspective."
```

#### Domain-specific review instructions per advisor

**API Advisor:** Endpoint contracts (HTTP methods, status codes, error formats), breaking changes to existing consumers, N+1 queries, input validation at boundaries, response shape intentionality. Internal consumer ergonomics — will the teammate consuming this endpoint understand the response shape from the URL and a single example? Clear naming, consistent patterns, predictable error formats.

**Brand Voice Advisor:** Read `Audience:` from CLAUDE.md (or ask). Critique label/copy professionalism for that audience, empty state helpfulness, error message specificity, tooltip value. Don't impose generic SaaS voice — match what *this audience* expects.

**Performance Advisor:** N+1 queries, missing indexes, unbounded queries, unnecessary re-renders, bundle size impact, caching opportunities.

**Security Advisor:** Review with **minimum 8/10 confidence** before reporting (zero-noise principle — false positives erode trust). Check:
1. Auth boundary enforcement — every endpoint checked for proper auth filters.
2. Attack surface census — enumerate new endpoints, webhooks, background jobs, WebSocket channels.
3. Data field exposure — are responses leaking fields that shouldn't be public? Check serializers/JSON output.
4. Injection vectors — SQL injection (raw queries, string interpolation in where clauses), XSS (unescaped user input in views, `dangerouslySetInnerHTML`), parameter tampering.
5. Secrets in code — no API keys, tokens, or credentials committed.
6. Dependency risk — new packages: known CVEs, install scripts.
7. CI/CD exposure — workflow files: unpinned actions, script injection via event context.

**Product Advisor:** *Valuable* — is the right thing being built for the right person?
1. Opportunity vs. solution: has this been framed as a real opportunity (what a specific user does moment-to-moment), or a solution dressed up?
2. Workflow coverage: does the flow match how the real user works? Flag features that handle one step and punt the rest.
3. Consistency: does this action work the same way as equivalent actions elsewhere in the product? Flag organ-rejection risks.
4. Behavior change: name the user behavior measurably different after this ships. "They'll click this button" is a tautology.
5. Workflow edges (not rendering edges): what happens to the user's *job* at 0/1/many records? UX owns rendering; you own whether the user can still complete their job.

**Taste Advisor:** *Joyful* — voice, conviction, memorability. Not heuristic compliance.
1. Opinionated defaults: where did we leave a config surface instead of deciding? Flexibility is a trap.
2. Single-mind coherence: feels like one taste, or committee-edited?
3. One-sentence distinctiveness: is there a thing this does that would be *wrong* to say about the alternative?
4. Voice at the moment-of-truth: copy at first run, error recovery, the "I'm not cut out for this" moment. "Something went wrong" is not voice.
5. Inevitability: if any element were removed, would it be obviously worse? If 3+ elements are removable without loss, it's over-decided by committee.

**UX Advisor:** see §4.4.1 below — full inlined protocol.

**Custom advisors:** Generate 4–6 review focuses derived directly from their POV statement. Each focus should be something concrete they would check in the actual code.

#### 4.4.1 UX Advisor protocol (inlined)

<!-- ━━━ INLINED: UX-ADVISOR ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     The UX critique protocol below is a substantial inlined skill — it
     covers persona identification, first-fixation reasoning, mental-math
     audits, Jakob's Law conformance, cognitive-bias scanning, accessibility
     and craft checks, and a structured output format.

     OPPORTUNITY: This is the single largest inlined section in fab and the
     clearest candidate for extraction. It deserves its own `ux-advisor` skill
     because: (1) it's useful standalone for ad-hoc design critiques outside
     fab, (2) it has its own reference library worth growing independently,
     (3) it can take optional inputs (screenshots, dev-server URLs) that
     warrant their own argument schema. Recommended action if you're building
     a plugin marketplace: extract this into a standalone skill and have fab
     compose it via `Skill: ux-advisor`. Kept inline so fab works on its own.
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->

You are a senior UX advisor. Your job is not to produce a checklist — it is to **narrate a reasoning chain** the user can argue with.

**Toolkit you bring:** visual flow & first-fixation reasoning, pattern fluency (you know UI vocabularies well enough to propose better ones), pixel precision (alignment, spacing rhythm, optical adjustments), color/gradient craft, copy craft, typography hierarchy, simplification instinct (less is usually right).

**Before you critique any screen, identify the audience.** Read `Audience:` from `CLAUDE.md`, or ask. The audience changes the reference tools (Jakob's Law), the bias profile, and what counts as "good." Examples:
- Operator/admin surfaces (engineers as users) — reference: Retool, Sentry, Datadog, Linear, GitHub. They want density, IDs, keyboard-friendliness; polish reads as wrong-audience.
- Decision-maker surfaces (analysts, investors, executives) — reference: domain-specific best-in-class tools. They're bias-exposed under time pressure; defaults, framings, anchors do real work.
- Consumer surfaces — reference: top consumer apps in adjacent categories. Aesthetic and microcopy matter more than density.

If you can't tell, **ask before critiquing**. Guessing wrong produces advice worse than none.

**Core principles** (the lens):

1. **Mental model formation** — the user forms a model within 1–2s, seeded by first fixation. If the model doesn't match the UI's actual model, every click feels wrong.
2. **Nielsen's 4 most-load-bearing heuristics**: status visibility, undo/freedom, recognition over recall, consistency. Then the rest.
3. **Don't make me think** (Krug) — self-evidence is the standard; self-explanatory is the fallback; self-teaching is failure.
4. **Mental math = split-attention** — every ping-pong across the screen is extraneous cognitive load. Fix with proximity (Gestalt), direct labeling, integrated labels.
5. **Progressive disclosure** — show the 20% of features that serve 80% of use cases; peel back as the user goes deeper. Failure modes: "Bloomberg terminal in React" (too much at once) and "guided wizard for a power user" (too little).
6. **Jakob's Law** — borrow patterns from the audience's reference tools. Originality is not a feature.
7. **Visual laws**: Fitts (target size & distance), Hick (decision time vs. choice count), Miller (~7 short-term-memory cap).
8. **Cognitive bias** — load-bearing on decision screens, lower-stakes on operational ones. Run anchoring / framing / defaults / confirmation / availability / authority-laundering / peak-end / serial position / social proof / cognitive fluency / base-rate-neglect / endowment. Apply the **Gigerenzer test** — does the shortcut actually harm the task, or is it ecologically rational? Apply the **dark-patterns mirror** — would this be called a dark pattern if the audience were consumers?
9. **Craft** — accumulation of invisible details: spacing rhythm (4/8 grid), typographic hierarchy (size+weight, not color alone), semantic color (green/amber/red mean things; brand gradients don't), microcopy precision, optical alignment, motion (200ms reads as polish; 500ms as sluggish).

**The protocol** — follow every step in order:

| Step | What |
|------|------|
| 0 | Identify audience and surface type. |
| 1 | Name the task in one bucket: Find / Compare / Analyze / Act. |
| 2 | First fixation — what does the eye land on first? What mental model does that seed? Quote it. |
| 3 | Model/affordance match — does the screen deliver on that model? Name mismatches precisely. |
| 4 | Walkthrough each primary action: (a) will they know what to do? (b) if they do, will they know they did it? |
| 5 | Mental math audit — list every instance where the user has to assemble information from multiple parts of the screen. Be exhaustive. |
| 6 | Jakob's Law audit — name the specific reference tool and pattern for each hit. |
| 7 | Cognitive bias audit — only flag biases where the harm is specific and real (Gigerenzer test). |
| 8 | Progressive disclosure audit — what's over-exposed, what's under-exposed. |
| 9 | Heuristic violations — only the ones that fail; don't list passing heuristics. |
| 10 | Fitts/Hick/Miller sanity check — skip if nothing fails. |
| 11 | Implementation quality: interaction states (idle/hover/loading/empty/error/success/disabled — read source via Grep for conditional rendering), accessibility (keyboard, ARIA, contrast ≥4.5:1 body / ≥3:1 large, touch targets ≥44×44px on mobile), pixel precision (4/8 grid, spacing tokens vs. hardcoded px), color & AI slop (purple/blue gradients, 3-col icon grids, decorative blobs, generic hero copy — flag if present), copy craft (labels name intent not action, empty states teach, error messages say what happened and what to do), typography (hierarchy via size+weight, tabular numerals for comparable numbers, monospace for IDs). |
| 12 | Affordance alternatives — propose 1–3 pattern swaps where the existing pattern is clearly worse than a known alternative. |
| 13 | Simplification — top 1–3 things to cut or collapse. |
| 14 | Verdict (one sentence) + the **single highest-leverage fix** — the one change that cascades into improving the rest. |

**Output format** — default to this structure:

```
**Audience + surface:** <audience> · <surface type>
**Task:** <one sentence, Find/Compare/Analyze/Act bucket named>
**First fixation:** <element> — seeds the model: "<quoted mental model>"
**Model/affordance match:** <match or mismatch, with reasoning>
**Walkthrough:** [primary actions with two-question check]
**Mental math:** [numbered list of split-attention instances]
**Jakob's Law:** Honors / Violates
**Cognitive bias:** [only biases with specific, real harm]
**Progressive disclosure:** over- / under-exposed
**Heuristic violations:** [only failures]
**Fitts/Hick/Miller:** [issues, or skip]
**Implementation quality:** states / a11y / pixels / color & slop / copy / type
**Affordance alternatives:** [1–3 swaps]
**Simplification — cut:** [top 1–3]
**Verdict:** <one sentence>
**Highest-leverage fix:** <the one change>
```

**Voice:** be specific; have opinions; name tradeoffs; skip preamble; no apologetic softening; write short.

**Anti-patterns to avoid:** generic verdicts ("feels cluttered"), checklist dumps, ten fixes instead of one, "just A/B test it," critiquing an admin surface for lacking polish, citing a heuristic without naming how it applies to *this* pixel, bias-hunting for its own sake, naming what's wrong without proposing an alternative when one obviously exists.

If reviewing live UI, take screenshots first (the dev server should already be running — see §4.3.5). Use any browser-automation tool you have — Playwright, Puppeteer, headless Chrome, or a manual screenshot is fine. Example with Playwright:

```bash
# Replace with your tool of choice; this is illustrative
npx playwright screenshot http://localhost:{port}/{relevant-page} /tmp/ux-review-desktop.png
npx playwright screenshot --viewport-size=375,812 http://localhost:{port}/{relevant-page} /tmp/ux-review-mobile.png
```

If the dev server isn't running, run the protocol from source code anyway. Flag visual concerns as "cannot verify without screenshots" but cover everything assessable from the diff.

### 4.5 Combine advisory feedback + fix loop

1. Collect all advisor reports.
2. Merge findings, removing duplicates, ordered by severity.
3. Dispatch the Staff Engineer again with the combined feedback.
4. Re-run ONLY the advisors whose findings were not addressed (max 3 cycles).
5. If issues persist after 3 cycles, include them in the Stage 5 notification.

When advisory fixes are clean: `echo "advisory=done" >> .fab`.

### 4.6 Standard code review

After advisory review is clean, run a standard code review from a different AI's perspective to catch bugs, correctness issues, and missing tests. Fix real defects before pressure-testing the design.

<!-- ━━━ INLINED: CODEX-REVIEW ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Standard code review uses the OpenAI Codex CLI. Invocation is straight
     CLI; no skill dependency. If you have OpenAI's "codex" Claude Code plugin
     installed, you can replace this block with `Skill: codex:review` for a
     richer integration (streaming output, structured findings, etc.).

     OPPORTUNITY: A "code-review" skill that wraps multiple second-opinion
     backends (codex, GitHub Copilot CLI, Gemini, custom MCP-based reviewers)
     would be a valuable extraction — fab could compose it without caring
     which backend the user prefers.
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->

```bash
codex review --base main -C ~/dev/{worktree-name}
```

Requires the `codex` CLI to be installed and authenticated. If `codex` is not available, STOP and report to the user: "Standard code review could not run — `codex` CLI is missing. Install from https://github.com/openai/codex or skip with explicit confirmation." Do NOT silently skip this stage.

If Codex finds Critical or Important issues, dispatch the Staff Engineer to fix them before proceeding.

When the standard review is clean (all Critical/Important issues fixed): `echo "codex_standard=done" >> .fab`.

### 4.7 Adversarial review

After standard review is clean, run an adversarial review to pressure-test the design itself.

```bash
codex review --base main -C ~/dev/{worktree-name} \
  "Adversarial review: challenge the implementation approach and design choices.
   Question assumptions, tradeoffs, failure modes, and whether a different
   approach would have been safer or simpler. This is not a bug hunt — ask
   whether it should have been built this way at all."
```

Optional focus text steers the review (e.g., "Focus on API contract stability and auth boundary enforcement" for an API feature).

**How to handle adversarial findings:**
- **Critical design concerns** ("this approach won't scale", "race condition in the auth flow") → dispatch Staff Engineer to fix.
- **Valid tradeoff observations** ("you chose simplicity over performance here") → include in the Stage 5 notification as "Design notes."
- **Speculative concerns** ("what if someday you need X") → ignore; YAGNI.

If the CLI fails, STOP and report. Do NOT silently skip.

When handled: `echo "codex_adversarial=done" >> .fab`.

### 4.8 Commit and start dev server

**HOOK-GATED STEP.** `git commit` is **blocked by the fab-gate hook** unless both `codex_standard=done` and `codex_adversarial=done` are recorded in `.fab`.

```bash
git add [specific changed files]
git commit -m "{TICKET_ID}: {title}"
echo "committed=$(git rev-parse --short HEAD)" >> .fab
```

Make sure the dev server (started in §4.3.5) is still running. If not, restart it.

### 4.9 Visual QA (if UI-observable)

After the dev server is running, perform an automated visual QA pass. Skip if the change is purely backend with no UI impact.

Use any browser-automation tool you have. Examples below use Playwright; substitute Puppeteer, Cypress, headless Chrome, or any equivalent.

1. **Navigate to the feature** and verify it loads:
   ```bash
   npx playwright screenshot http://localhost:{port}/{relevant-page} /tmp/fab-qa-{TICKET_ID}-desktop.png
   ```

2. **Check the rendered page contains the expected elements** from the EARS requirements (use a snapshot/ARIA tree dump or DOM check from your tool).

3. **Check for console errors** — any new JS errors or warnings are findings to fix.

4. **Take screenshots for the user:**
   - Desktop (1280×800)
   - Mobile (375×812)

5. **Verify key interactions** if the feature has them: click primary buttons, fill new form fields, verify state changes as expected.

6. **If issues found:** dispatch Staff Engineer to fix, re-run QA. Max 2 cycles.

7. **Collect QA evidence** for the notification: screenshot paths, console health, interactions verified.

---

## Stage 5: Notification (autonomous → YOU test)

```
Fabrication complete!

Ticket: {TICKET_ID} — [Title]
Test at: http://localhost:[port]/[relevant-page]

What was built:
- [2-3 bullets of what was implemented]

Visual QA: [Clean / N issues fixed]
  Desktop: [screenshot path]
  Mobile:  [screenshot path]
  Console: [clean / warnings]

Review results: [Clean / N findings fixed in M cycles]
Tests: [All passing / X passing, Y skipped]

Worktree: ~/dev/{worktree-name}

Ready for your testing. Tell me what needs adjusting, or say "ship it" when you're happy.
```

---

## Stage 6: Feedback Loop (YOU give feedback → autonomous fixes)

If the user reports issues (UI tweaks, bugs, label changes, spacing, etc.):

1. Dispatch a fix agent to the worktree with the specific feedback.
2. The fix agent makes changes, runs tests, commits.
3. Tell the user to refresh and check.

Repeat until the user is satisfied. Each round should be fast — these are typically small tweaks.

---

## Stage 7: Ship (YOU say "ship it" → autonomous)

When the user says "ship it":

1. **Push the branch:**
   ```bash
   git push -u origin {branch-name}
   ```

2. **Create the PR** (hook-gated — requires `committed=` in `.fab`):
   ```bash
   gh pr create --title "{TICKET_ID}: {title}" --body-file /tmp/fab-pr-body.md
   echo "pr=$(gh pr view --json number -q .number)" >> .fab
   ```
   PR body should link the spec, summarize changes, and include a test plan.

3. **Run automated review fixes and CI monitoring in parallel:**

   <!-- ━━━ INLINED: GREPTILE-FIX ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Greptile (https://greptile.com/) is an automated AI code reviewer that
        posts inline PR comments. The two-pass strategy below catches both fast
        reviews (small PRs ~1-3 min) and slow reviews (large PRs up to 10 min).

        OPPORTUNITY: This deserves its own `code-review-fix` skill that handles
        any AI reviewer (Greptile, CodeRabbit, Cursor BugBot, Diamond, etc.) —
        the inline-comment + reply pattern is identical across them. Extract
        when you find yourself adding a second backend.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->

   **Two-pass automated-review check** (Greptile or equivalent):
   - **Pass 1 (early):** ~90s after PR creation, fetch any AI-reviewer comments via `gh api repos/owner/repo/pulls/{N}/comments`. For each:
     - Critically evaluate — automated reviewers are not gospel. They suggest changes that break conventions, flag intentional design decisions, recommend over-engineered abstractions, misunderstand context, and produce false positives.
     - For valid findings: fix and reply `✅ Fixed in commit {SHA}` via `gh api repos/.../comments/{ID}/replies`.
     - For invalid findings: reply `❌ Dismissed — {reason}`.
     - For findings needing manual review: reply `⏭️ Skipped — {reason}`.
     - Commit fixes and push.
   - **CI monitoring:** poll `gh pr checks` until all complete. Auto-fix CI failures (max 2 cycles).
   - **Pass 2 (after CI):** check for new automated-review comments one more time. Large diffs often have late-arriving reviews. Repeat the evaluate/fix/reply loop.

   Only record `greptile=done` after pass 2: `echo "greptile=done" >> .fab`.

4. **Update tracker** if applicable (e.g., `linear issue update {TICKET_ID} --state "Needs Review"` or `gh issue edit {N} --add-label review-ready`).

5. **Report back:**
   ```
   Shipped!
   PR: [URL]
   CI: [passing/pending]
   Automated review: [clean / N comments fixed]
   Tracker: [URL] (status updated)
   ```

---

## Stage 8: Doc Audit (autonomous, runs with PR)

After creating the PR, scan project docs for content that drifted from the changes:

1. **Identify docs to check:**
   ```bash
   find . -maxdepth 2 -name "*.md" -not -path "./.claude/*" -not -path "./node_modules/*" | head -20
   ```

2. **Cross-reference the diff against each doc:**
   - `README.md` — setup instructions, feature lists, screenshots
   - `CLAUDE.md` — architecture boundaries, commands, conventions
   - `ARCHITECTURE.md` — data flow descriptions, system diagrams
   - `CHANGELOG.md` — add an entry for this change (if used)
   - Any doc that references files, endpoints, or components that were modified

3. **Update stale docs** in the same PR branch:
   ```bash
   git add [changed docs]
   git commit -m "{TICKET_ID}: update docs for {feature}"
   git push
   ```

4. If no docs need updating, skip silently. Don't create empty doc commits.

5. Record completion: `echo "doc_audit=done" >> .fab`.

---

## Stage 9: Retro Comment

Leave a structured retrospective on the spec so the team has context.

```markdown
## Fab Retro

**Approach:** {scope mode from §2.0} — {1 sentence on what was built}

**Product challenge outcome:** {Did we change direction from the original ask? What alternative was chosen and why?}

**Metrics:**
- Implementation: {N} phases, {M} files changed, {L} lines added
- Tests: {X} new tests
- Review cycles: {N} advisory, {M} codex
- Visual QA: {clean / N issues fixed}
- CI: {passed first try / N fix cycles}

**Design notes:** {Tradeoff observations from adversarial review}

**What went well:** {1–2 specifics}

**What to watch:** {1–2 things to monitor}

**Canon lesson:** {One sentence capturing what this feature taught us about
product judgment that should sharpen the next fab. Skip if there's no
non-obvious lesson — don't manufacture one. If the lesson is durable and
general to this project, append it to CLAUDE.md under a `## Local canon`
section so future fabs pick it up.}
```

Post the retro: `linear issue comment add {TICKET_ID} --body-file ...`, `gh issue comment {N} --body-file ...`, or append to `.fab/specs/{TICKET_ID}.md` for local-spec mode.

Record: `echo "retro=done" >> .fab`.

**After recording `retro=done`, check `.fab` for any missing stages.** All lines should be present: `implementation`, `advisory` (or `advisory=skipped`), `codex_standard`, `codex_adversarial`, `committed`, `pr`, `greptile`, `doc_audit`, `retro`. If any are missing, complete them before reporting fab as done.

---

## Error Handling

### Implementation agent reports BLOCKED
Surface the blocker with context. Ask: "Implementation hit a blocker: [description]. How would you like to proceed?"

### Implementation agent reports NEEDS_CONTEXT
Try to gather the needed context. If still insufficient, ask the user.

### Worktree creation fails
**Do NOT fall back to working in the main repo.** Report failure reason. Suggest: check dev slot availability, disk space, branch conflicts.

### Tests fail persistently
After 2 fix attempts: "Tests are failing after 2 fix attempts. Here's what's failing: [details]. Want me to keep trying or look at this together?"

---

## What Fab Does NOT Do

- **Does not accept the user's first framing uncritically.** Stage 1 challenges premises before building.
- **Does not run without user approval of the spec.** Stage 3 is mandatory.
- **Does not merge the PR automatically.** Stage 4 (Land) is user-initiated.
- **Does not skip review stages.** Both standard and adversarial reviews are hard gates enforced by the fab-gate hook — `git commit` is literally blocked until both `codex_standard=done` and `codex_adversarial=done` are recorded.
- **Does not skip visual QA** if the feature has UI.
- **Does not skip worktree creation.** Every fab runs in a dedicated worktree.
- **Does not modify files outside the worktree.** Your main repo is untouched.

---

## Extracting inlined sections

This skill is intentionally self-contained — it has zero plugin dependencies. The cost of that is size: several substantial protocols are inlined that could each stand alone as their own skill. Each inlined section starts with an `INLINED:` HTML comment block calling out the extraction opportunity:

| Section | Inlined as | Where |
|---------|-----------|-------|
| Sharpen (product challenge) | Stage 1 | `## Stage 1` |
| Create-worktree | Stage 4.1 (script: `create-worktree.sh`) | `### 4.1` |
| UX Advisor protocol | Stage 4.4.1 | `#### 4.4.1` |
| Standard code review (codex CLI wrapper) | Stage 4.6 | `### 4.6` |
| Greptile / automated review fix | Stage 7 step 3 | `### Stage 7` |

If you maintain a Claude Code plugin marketplace, extracting any of these into standalone skills lets fab compose them via the `Skill` tool (`Skill: yourplugin:sharpen`) instead of carrying the inline body. The tradeoff is users must install your plugin too. This standalone repo errs on the side of self-containment.
