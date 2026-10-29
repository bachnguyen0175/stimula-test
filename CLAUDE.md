# Reel Good (factory practice demo)

A small Next.js movie browser on TMDB data, used to test the STIMULA software factory
against a private GitHub test repo. Nobody depends on it.

## Commands

```bash
npm install
npm run dev                       # needs TMDB_API_KEY in .env.local, or TMDB_USE_MOCKS=true
npm test                          # vitest, uses committed fixtures, no network
npm run typecheck                 # tsc --noEmit
npm run lint                      # eslint
./.claude/scripts/gates.sh full   # the factory's deterministic verdict
```

## Conventions

- Next.js App Router (`app/`), React server components by default. Add `"use client"` only
  when a component needs browser state.
- All TMDB access goes through `lib/tmdb.ts`, which imports `server-only`. Never read
  `TMDB_API_KEY` anywhere else and never expose it through a `NEXT_PUBLIC_*` variable.
- Tests live next to the code as `*.test.ts` and use `lib/tmdb-fixtures.ts`, never the
  network.
- Existing test files are protected by `.claude/hooks/protect-tests.sh`. Add a new test
  file instead of editing an existing one.

---

# Factory rules

This repository runs a software factory. Read `docs/factory/CONTRACT.md`, then
`docs/factory/CHARTER.md`, before acting. The contract is the source of truth for queue semantics and
non-negotiable rules.
For first-time setup and the local dry run, follow `docs/factory/README.md`.

## Read first

The live queue is GitHub issue labels plus `factory-handoff:v1` comments.
`docs/factory/QUEUE.md` is a snapshot for humans and audit, so an unmerged snapshot must
never be used as the handoff between routines.

## Non-negotiable

1. **Never merge.** GitHub branch protection is the enforcement boundary; the local hook is
   a second layer.
2. **Never edit factory policy** unless the human explicitly asks in this session. Protected
   paths are listed in the contract.
3. **Never modify an existing test in an unattended run.** An interactive change needs
   explicit human approval and a human read.
4. **Gates fail closed.** Quote the `FACTORY_GATES:` line verbatim. `RED`,
   `MISCONFIGURED`, and required skips all block progress.
5. **Verification uses a fresh context.** Delegate to `factory-verifier`.
6. **Claim one live issue per run.** Win the deterministic remote-branch claim described in
   the contract, then replace `factory:ready-to-implement` with `factory:in-progress`.

## Stopping conditions

Stop and hand back to a human when any of these is true:

- gates went red twice on the same item
- the work turns out to touch a `LOAD_BEARING` path
- the diff would exceed the charter's line limit
- the item is still ambiguous after one clarification attempt
- the review queue is already at the charter's limit

The last one is the important one and the easiest to ignore. The constraint on this factory
is not how many agents can run in parallel. It is how many decisions are pending a human's
judgment at once. When that queue is full, producing more is not progress.

## State lives in files, not conversations

Write one immutable record under `docs/factory/runs/` using its documented format. Update
GitHub labels for operational state. Sessions end and transcripts are not the queue.

## Writing for the next reader

Commit messages and PR bodies are written for someone who was not in this session and
cannot ask you what you were thinking. On a `client-production` repo, assume that reader is
not the author and the time is six months from now.
