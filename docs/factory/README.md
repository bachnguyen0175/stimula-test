# Factory operating guide

This directory is the durable operating state for the repository's software factory. Start
here after installing the template into a project.

The first safe milestone is modest: the charter describes the project accurately, the
required gates run locally, and Claude Code can report what it would do without writing
anything.

## Configure once

1. Review [CHARTER.md](CHARTER.md). Choose one tier, replace the example paths and work
   categories, set the review-queue limit, and leave `CHARTER_STATUS` as `incomplete` until
   every section has been read.
2. Configure `../../.factory/gates.conf`, then run:

   ```bash
   ./.claude/scripts/gates.sh fast
   ./.claude/scripts/gates.sh full
   ```

3. Replace the project placeholders and command examples at the top of
   [`CLAUDE.md`](../../CLAUDE.md).
4. Preview the GitHub labels with `./.factory/scripts/bootstrap-github.sh`. Add `--apply`
   only after confirming the target repository.
5. Configure branch protection or a GitHub ruleset using [GITHUB.md](GITHUB.md).
6. Run `./.factory/scripts/doctor.sh`, review the installation diff, commit, and push.

Cloud sessions start from the remote repository. An unpushed factory does not exist from
their point of view.

## Use it from Claude Code

The installed project commands are:

- `/factory` reports the live queue, gate health, and work needing human judgment.
- `/factory-tune` reviews evidence and proposes constraint changes.
- `factory-triage`, `factory-spec`, `factory-implement`, `factory-verify`, and
  `factory-monitor` are the workflow skills.

Cloud routines, their prompts, and the cloud environment setup are in
[ROUTINES.md](ROUTINES.md). Create the triage routine first and nothing else.

Begin with a report-only triage request:

```text
Run the factory-triage skill in report-only mode. Do not write files or apply labels.
Explain every proposed disposition using the charter.
```

## Models per stage

| Stage | Where the model is set | Model | Why |
|---|---|---|---|
| Triage | `factory-triage` skill | `haiku` | Runs on every issue, hourly; rules already bias unclear items to the slower path |
| Spec | `factory-spec` skill | `opus` | Design decisions are where mistakes cost most |
| Implement | **the routine or your session** (`/model`) | Sonnet by default, Opus for a load-bearing slice | Left unset in the skill on purpose: a skill model overrides the session for the turn and would replace your deliberate choice |
| Verifier | `factory-verifier` agent | `opus` | Independent reader, different model from the writer |
| Critic | `factory-critic` agent | `sonnet` | Second lens on load-bearing designs |
| PR verify | `factory-verify` skill | `opus` | Same reasoning as the verifier |
| Monitor | `factory-monitor` skill | `sonnet` | Weekly sweep of CI and advisories |

Aliases follow the newest model of each family. A model missing from `.factory/prices.json`
makes run costs `unknown` until you add its price. Two settings override these choices:
a model passed when a subagent is spawned (the implement skill forbids it for the verifier)
and `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`, which `doctor.sh` warns about. A skill's model also
yields to an organization's `availableModels` allowlist and to models auto mode does not
support.

## Which file owns what?

| File | Role |
|---|---|
| [CHARTER.md](CHARTER.md) | Human-owned risk, scope, autonomy, and stop decisions |
| [CONTRACT.md](CONTRACT.md) | Non-negotiable rules every session follows |
| [GITHUB.md](GITHUB.md) | Queue-label and repository-enforcement setup |
| [QUEUE.md](QUEUE.md) | Reviewable queue snapshot; GitHub labels remain live state |
| [STATE.md](STATE.md) | Compact human-readable health snapshot |
| [DECISIONS.md](DECISIONS.md) | Accepted constraint changes and their evidence |
| [`runs/`](runs/README.md) | One immutable record per execution |

## Daily operating rule

Read the control room before starting more work. When the number of items awaiting review
reaches the charter limit, stop producing. The factory's useful throughput is bounded by
what a human can verify and understand, even when generation itself is cheap.
