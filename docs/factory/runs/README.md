# Factory run records

Write one immutable Markdown file per run. This avoids merge conflicts between parallel
routines and leaves enough structured evidence to measure the factory later.

Use a filename that is unique without coordination:

```
YYYY-MM-DDTHHMMSSZ-<stage>-<issue-or-run-id>.md
```

Start each file with this front matter:

```yaml
---
run_id: 2026-08-18T153012Z-implement-142
stage: triage | spec | implement | verify | monitor
started_at: 2026-08-18T15:30:12Z
finished_at: 2026-08-18T15:41:09Z
status: succeeded | stopped | rejected | infrastructure-failed
issue: 142 | none
pull_request: 318 | none
gate_level: fast | full | deep | none
gate_status: GREEN | RED | MISCONFIGURED | not-run
verifier: accepted | accepted-with-reservations | rejected | not-run
human_required: true | false
models: claude-sonnet-5-5, claude-opus-5-5 | unknown
cost_usd_estimate: 0.8421 | unknown
cost_source: transcript | none
proof_note: none | <how the old behaviour was checked when prove-test.sh said WEAK>
blocked_by: none | <hook name or command> (<factory | user-level | managed>): <what it blocked>
---
```

Set `proof_note` whenever `prove-test.sh` printed `status=WEAK`: what the verifier ran
against the old behaviour and how it failed. Otherwise write `none`.

Set `blocked_by` whenever a hook blocked a tool call: name the hook (its script or the
name in its message), where it comes from (`factory` for `.claude/hooks/`, `user-level`
for `~/.claude/settings.json`, `managed` for organisation settings), and what it blocked.
"A hook blocked some writes" is not enough: a factory block is a guardrail working, while a
user-level block is local noise that cloud runs won't see. `doctor.sh` lists user-level
hooks.

Fill `models`, `cost_usd_estimate` and `cost_source` by pasting the output of
`./.factory/scripts/run-cost.sh` just before you write the record. Never type a cost
yourself. The script reads this session's transcript, including subagents, and prices it
with `.factory/prices.json`. The figure is an API-list-price estimate: on a subscription
plan it shows where usage goes, not what is billed. If it prints `unknown`, record
`unknown`.

Then record what was checked, what changed, what was clean, and why the run stopped. Do not
include secrets, full transcripts, or copied issue bodies. Link to those systems instead.

These records support simple measurements without a separate service: queue age, gate
failure rate, verifier rejection rate, time to review, and escaped defects linked back to a
run or pull request.

