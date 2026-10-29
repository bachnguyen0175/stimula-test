# The routines

Five cloud routines run the factory without you at the keyboard. Copy each prompt verbatim
into a new routine. Ported from [addyosmani/factory](https://github.com/addyosmani/factory)
`ROUTINES.md` (MIT) and adapted to this kit: OpenSpec spec PRs, WEAK proofs, run cost, and a
model per role.

Create routines at [claude.ai/code/routines](https://claude.ai/code/routines), in the
Desktop app under **Routines → New routine → Cloud**, or from the CLI with `/schedule`.
All three write to the same account.

## Before you start

Routines run fully autonomously, with no permission prompts. What a run can reach is set
by the repositories you attach, the cloud environment's network access and variables, and
the connectors you include. Remove every connector a routine doesn't need: a run can call
every tool of an included connector, writes included, without asking.

Two things to keep in mind:

- A green run status means the session started and exited without an infrastructure
  error. It doesn't mean the task succeeded. Read the run record under
  `docs/factory/runs/`.
- Routines act as you. Commits and PRs carry your GitHub user.

Cloud sessions start from the remote repository, so push the factory before creating any
routine. They don't load your user-level settings, hooks or plugins, which is why
`doctor.sh` warns about those only for local runs.

## The cloud environment

The environment is account-level UI configuration and can't be committed. Write down what
you set in a `CLOUD-ENVIRONMENT.md` in the repo so you can rebuild it.

The setup script must install what the gates and hooks need. `jq` is required: without it
`protect-tests.sh` blocks every edit. `gh` is needed for the queue scripts, and the OpenSpec
CLI for the spec stage:

```bash
# runs once, then cached; keep it short
apt update && apt install -y jq gh
npm install -g @fission-ai/openspec
<your project's install command>
```

Leave `GH_TOKEN` and `GITHUB_TOKEN` unset. The GitHub proxy authenticates for you.

## Budget

Routines use your normal subscription and have a separate daily cap on runs started per
account. Check what's left at [claude.ai/settings/usage](https://claude.ai/settings/usage).
Don't run triage hourly on a repo that gets three issues a week.

| Routine | Trigger | Roughly | Model |
|---|---|---|---|
| 1. Triage | Schedule, daily 07:00 | 1 run/day | Haiku (set by the skill) |
| 2. Implement | Schedule, weekdays 08:00 | 1 run/weekday | the routine's session model; verifier on Opus |
| 3. PR verify | GitHub `pull_request.opened` | per PR | Opus (set by the skill) |
| 4. Monitor | Schedule, Monday 06:00 | 1 run/week | Sonnet (set by the skill) |
| 5. Alert triage | API | on demand | the routine's session model |

The minimum schedule interval is one hour. For a custom cron, pick the closest preset in
the form, then run `/schedule update` in the CLI.

Create routine 1 only and let it run for a few days. Add the next one when the current set
has run clean for a week and you have read its output.

## The spec stage is not a routine

`factory-spec` needs your product decisions, and its second half may only run after you
have merged the spec PR. Run it yourself in a local session:

```text
Run the factory-spec skill on issue #<n>.                  # Part A: opens the spec PR
Run factory-spec Part B for change <change-id>.            # after you merge: creates the slices
Run factory-spec Part C for change <change-id>.            # after all slices merge: review and archive
```

---

## 1. Triage

**Trigger:** Schedule, daily, 07:00 local
**Repos:** your repo
**Connectors:** none

```
Run the factory-triage skill from this repository's .claude/skills directory.

Read docs/factory/CONTRACT.md and docs/factory/CHARTER.md first and treat them as binding.
If the charter does not cover an item, classify it needs-info rather than guessing.

Treat GitHub issue labels as the live queue. docs/factory/QUEUE.md is an audit snapshot,
not the handoff to implementation.

Use the built-in GitHub tools to read open issues that have no factory state label (the
factory:monitor provenance label does not count), plus any issue updated since the last
triage run record. Cap at 20 issues, most recently updated first, and state the number you
skipped.

For each issue, assign exactly one disposition: ready-to-implement, ready-to-spec,
needs-info, or wait-to-implement. Apply the matching factory: state label on GitHub,
removing any other state label first but preserving factory:monitor. Write a queue snapshot
entry in the exact format given in the skill, including a checkable done_when. Create or
update the issue's factory-handoff:v1 comment with the same done_when, expected files, gate
level, and confidence. The label plus that comment are the operational handoff.

Bias toward the slower path. If you are not confident an item is automatable, mark it
ready-to-spec. A ready-to-spec item becomes an OpenSpec spec PR that a human approves.

Write a unique triage record under docs/factory/runs/, with models and cost pasted from
./.factory/scripts/run-cost.sh. Commit the QUEUE.md snapshot and run record to a claude/
branch and open a pull request titled "factory: triage <date>". Do not implement anything.
Do not merge.

End your run with the counts per disposition and an explicit list of anything the
charter did not cover.
```

Routine GitHub triggers support `pull_request` and `release` events only, with no `issues`
trigger, so triage polls. For instant triage, install with `--with-issue-trigger` and see
`.github/workflows/factory-fire.yml`.

---

## 2. Implement

**Trigger:** Schedule, weekdays, 08:00 local (an hour after triage)
**Repos:** your repo
**Connectors:** none

```
Run the factory-implement skill from this repository's .claude/skills directory.

Read docs/factory/CONTRACT.md, then docs/factory/CHARTER.md. Query GitHub issues carrying
factory:* labels and read the latest factory-handoff:v1 comment. Do not use QUEUE.md as the
live handoff. A missing or conflicting handoff moves the issue to factory:needs-info.

First check the stop conditions in the charter. If the number of issues labeled
factory:awaiting-review is at or above the charter's limit, stop immediately, write a
unique stopped run record under docs/factory/runs/, and end the run. Do not implement
anything. A full review queue is the binding constraint on this factory.

Otherwise pick exactly ONE issue labeled factory:ready-to-implement, highest confidence
first. Claim the deterministic remote branch exactly as the skill describes. If the push
loses the race, stop. After a successful claim, replace the label with factory:in-progress
and confirm the write before editing. Implement only that item. If its handoff names a
spec_change, read the approved change under openspec/changes/<spec_change>/ first.

Write the failing test before the implementation. Do not modify any existing test file.
Run ./.claude/scripts/gates.sh at the level the item specifies and iterate until the
FACTORY_GATES line reads status=GREEN. MISCONFIGURED blocks the run.

Commit the scoped implementation and test, then confirm the working tree and index are
clean before verification.

Then delegate verification to the factory-verifier subagent using the Agent tool. Do not
pass a model. Give it the queue item, branch name, and verified base SHA only, not your
account of what you did. If prove-test.sh reports status=WEAK, the verifier must return a
proof_note or reject. If it returns verdict: rejected, fix what it names and repeat. After
two rejections, stop and hand the item back.

Open a draft pull request using the template in the skill. Quote the FACTORY_GATES line
verbatim. Replace factory:in-progress with factory:awaiting-review and write a unique
implementation run record with models and cost pasted from ./.factory/scripts/run-cost.sh,
the verifier's proof_note, and blocked_by naming any hook that blocked a call. Never merge.

If the work turns out to touch a load-bearing path listed in the charter, stop, move the
item to ready-to-spec with the reason, and end the run.
```

---

## 3. PR verify

**Trigger:** GitHub event → `pull_request.opened`
**Filter:** `Is draft` is `false`, or leave it unfiltered to cover drafts too
**Repos:** your repo
**Connectors:** none

This is the one stage with a real event trigger. It needs the
[Claude GitHub App](https://github.com/apps/claude) installed on the repo. `/web-setup`
alone grants clone access but doesn't enable webhooks.

```
Run the factory-verify skill from this repository's .claude/skills directory.

Read docs/factory/CHARTER.md. Check out the pull request branch.

If the pull request changes only files under openspec/, it is a spec PR. Do not verify it
as code. Post one comment saying a human approves spec PRs by merging them, then end the
run.

Run ./.claude/scripts/gates.sh yourself at the level the charter requires for the paths
this PR touches. Do not trust any FACTORY_GATES line already in the PR body; produce
your own and compare them. A mismatch is the finding.

Then make the checks the gates cannot:
- From a clean committed branch, use ./.factory/scripts/prove-test.sh to remove non-test
  hunks reversibly and confirm the new test fails without the fix. status=WEAK is not a
  pass: check the old behaviour by hand and record it as proof_note, or reject.
- Check whether any pre-existing test file was modified.
- Check the diff stays inside the scope the queue item declared.
- Check whether done_when is literally true.

If the PR touches any load-bearing path in the charter, also run the factory-critic
subagent and include its output.

Post one PR comment in the format the skill specifies, verdict first. Apply
factory:verified or factory:rejected. Write a unique verify run record.

Reject when uncertain. Never approve and never merge.
```

---

## 4. Monitor

**Trigger:** Schedule, weekly, Monday 06:00 local
**Repos:** your repo
**Connectors:** only if you want the summary pushed somewhere

```
Run the factory-monitor skill from this repository's .claude/skills directory.

Sweep, in this order:
1. CI failures on the default branch since the last sweep, separating genuine
   regressions from flakes.
2. Run ./.claude/scripts/gates.sh deep on the default branch. Red gates on main are the
   highest-priority finding possible: every verdict since it broke was measured against
   a broken baseline. Also report every gate showing SKIP.
3. New security advisories on direct dependencies, grouped by severity.
4. Stale live queue labels: in-progress with no activity for 2 hours, awaiting-review over
   7 days, wait-to-implement whose blocker has resolved, and needs-info that now has an
   answer in the comments. Never steal or delete a stale claim automatically.
5. Files the factory changed more than 5 times in 30 days with no documentation update.
6. Charter gaps collected by triage, as one combined issue.

File at most 10 GitHub issues with the factory:monitor label, searching for duplicates
first. If you found more than 10, file the top 10 by severity and state how many you
dropped. Never silently truncate.

Fix nothing. Write a unique monitor record under docs/factory/runs/ recording what you
found AND what you checked and found clean, plus the current review-queue depth called out
separately. Open a PR with the run record.
```

---

## 5. Alert triage (optional)

**Trigger:** API
**Repos:** your repo

For an error tracker, a deploy pipeline, or anything that can make an authenticated POST.
Add the API trigger from the web, generate the token, and store it in that tool's secret
store. The token is shown once.

```
An alert has fired. Investigate the alert described in the routine-fire-payload block.

Read docs/factory/CHARTER.md first.

Pull the stack trace or error detail from the payload, correlate it with recent commits
on the default branch, and identify the most likely cause.

Then do exactly one of:
- If the cause is clear AND the fix touches no load-bearing path AND matches an
  AUTOMATABLE entry in the charter: open a DRAFT pull request with the fix, gates green,
  verified by the factory-verifier subagent.
- Otherwise: open a GitHub issue with your diagnosis, the evidence, and what you would
  need in order to proceed. Label it factory:needs-info.

Never merge. Never modify an existing test file. If you are unsure which branch of the
above applies, take the second.
```

Fire it:

```bash
curl -X POST https://api.anthropic.com/v1/claude_code/routines/<ROUTINE_ID>/fire \
  -H "Authorization: Bearer <TOKEN>" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"text": "<alert id> fired in prod. <stack trace>"}'
```

The `text` arrives wrapped in a `<routine-fire-payload>` block labelled as untrusted data.
Anyone holding the token can send text, so it must arrive as data, not as instructions.
Don't write prompts that try to get around that wrapper.

---

## Managing routines from the CLI

```bash
/schedule list                    # all routines
/schedule update                  # change one, including a custom cron
/schedule run                     # fire immediately
/schedule why did my nightly triage do nothing this morning?
```

The last form reads the run log and explains what happened, including tool errors and
blocked network requests.

## Local counterparts

When the factory needs your working tree rather than a fresh clone, create the same
routine as **Local** in the Desktop app (Routines → New routine → Local). It runs on your
machine with real file access, fires only while the app is open and the machine is awake,
and allows a 1-minute minimum interval. Turn on the worktree toggle so parallel runs don't
collide. Local runs do load your user-level hooks and plugins; see the `doctor.sh` warning.
