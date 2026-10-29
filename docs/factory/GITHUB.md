# GitHub setup

GitHub carries the factory's live queue and its merge boundary. This page records the
repository-side setup that cannot be inferred safely from Markdown alone.

## Queue labels

Preview and create the labels:

```bash
./.factory/scripts/bootstrap-github.sh
./.factory/scripts/bootstrap-github.sh --apply
```

Queue-state labels are mutually exclusive. `factory:monitor` is provenance and may coexist
with one issue state. `factory:verified` and `factory:rejected` belong on pull requests.

## Default-branch rules

Create a GitHub ruleset or branch-protection rule for the actual default branch. At
minimum:

- require changes to arrive through a pull request
- block force pushes and branch deletion
- do not grant the account used by unattended agents a bypass
- require the repository's CI checks once they exist

Whether you require human approvals depends on the repository tier and team. The factory
itself never approves or merges, even when GitHub would permit it.

On a private repository, rulesets and branch protection need GitHub Pro (or a paid
organization plan). On GitHub Free, the API returns 403 until the repository is public.

If routines run under your own GitHub account, GitHub can't tell your merge from an agent's.
Requiring one approval then blocks you, because you can't approve your own pull request, and
does nothing extra against an agent with the same rights. Use 0 required approvals and no
bypass: the rule still forces every change through a pull request. Agents are kept from
merging by the `block-merge.sh` hook and the skills. To make GitHub enforce it, run the
routines under a separate machine account that has no merge rights.

The committed Claude Code hooks block common shell routes to merging and direct
pushes. They cannot cover every hosted tool or API path, so a repository-side rule remains
the enforcement boundary.

## Claim branches

Implementation runs claim work through `claude/fq-<issue-number>`. The first run pushes a
unique empty claim commit without force. A later run starts from the same base with a
different claim commit, so Git rejects its non-fast-forward push. Two pushes at the same
moment get `cannot lock ref ... reference already exists` instead; either way the item is
claimed.

If a claim is stale, inspect the issue, branch, cloud session, and latest run record. A
human may then delete or recover the branch. Monitoring reports stale claims but never
steals them automatically.

