# Design: search movies by title

## Context

The home page (`app/page.tsx`) is a server component. It calls `getHomeMovies()` from
`lib/tmdb.ts` and renders a hero plus two `MovieGrid` sections. All TMDB access goes
through `lib/tmdb.ts`, which imports `server-only`, reads `TMDB_API_KEY`, and short-circuits
to `lib/tmdb-fixtures.ts` when `TMDB_USE_MOCKS=true`. The project runs Next.js 16, where
page `searchParams` is a Promise. It has no component-testing library, and adding one
would touch `package.json`, which is load-bearing.

## Goals / Non-Goals

**Goals:** submit-to-search on the home page; matching cards; a no-match empty state; an
empty query falls back to the normal home page; mock mode works with no network; the
credential stays on the server.

**Non-Goals:** see "What we are deliberately not doing" in `proposal.md`. That covers
search-as-you-type, pagination, filters, a separate route, new mock detail pages, and new
dependencies.

## Touched modules

| Path | Load-bearing | Change |
|---|---|---|
| `lib/tmdb.ts` | **yes** | add `searchMovies(query)`; let `request()` take extra query params |
| `lib/tmdb-fixtures.ts` | no | add one search-only fixture (*Inception*, id 27205) |
| `lib/tmdb-search.test.ts` | no (new) | boundary tests: mock hit, mock miss, live URL, missing key |
| `lib/search-query.ts` | no (new) | `parseSearchQuery(raw)`: turns `searchParams.q` into a trimmed string or `null` |
| `lib/search-query.test.ts` | no (new) | unit tests for the parser |
| `components/search-form.tsx` | no (new) | a plain GET `<form action="/">` with a labelled `<input name="q">` |
| `app/page.tsx` | no | read `searchParams`; branch between home and search results |
| `app/globals.css` | no | styles for the form and the empty state |

`lib/tmdb.test.ts` is **not** modified. It is an existing, protected test file.

## Data shapes

```ts
// lib/tmdb.ts (new export)
export async function searchMovies(query: string): Promise<MovieSummary[]>

// lib/search-query.ts (new)
export function parseSearchQuery(raw: string | string[] | undefined): string | null
// "  inception " -> "inception";  "" | "   " | undefined -> null;  ["a","b"] -> "a"
```

`searchMovies` returns the existing `MovieSummary` type, so `MovieGrid` and `MovieCard`
render the results unchanged. No exported type changes.

## Call flow

```
GET /?q=inception
  app/page.tsx  (server)
    q = parseSearchQuery((await searchParams).q)
    q === null  -> existing home path (getHomeMovies -> hero + two grids)
    q !== null  -> searchMovies(q)
                     mock:  filter fixture catalog by case-insensitive title substring
                     live:  request("/search/movie", { query: q })  -> results.map(toSummary)
                   -> results.length ? <MovieGrid ...results> : <empty state "No movies matched “q”">
    MissingTmdbKeyError (either path) -> <SetupNotice />
```

The search form is rendered on both paths, above the content, with `defaultValue={q ?? ""}`.
It is a plain HTML GET form, so it needs no `"use client"` and no JavaScript, and Back
works natively.

`request()` currently builds `new URL(TMDB_API_URL + path)` and sets `api_key` and
`language`. The change adds an optional `params: Record<string, string>` that is applied
with `url.searchParams.set`, so the query is encoded by `URLSearchParams` and never
concatenated into the path. As a cheap guard, `searchMovies` returns `[]` for a blank
query without making a request.

Mock catalog = `mockTrending ∪ mockPopular ∪ [mockDetail] ∪ mockSearchOnly`, deduplicated
by id. Matching is a case-insensitive `includes` on the title.

## Load-bearing paths involved

- `lib/tmdb.ts`: the server-only TMDB boundary, which holds the API key path. Only slice 1
  touches it. That slice is `load_bearing: true`, `gate_level: deep`, and needs a human read.
- `package.json` is **not** touched, so no new dependencies.

## What could break elsewhere

- **Home page caching.** `app/page.tsx` exports `revalidate = 900` and is statically
  rendered today. Reading `searchParams` makes it render per request. TMDB fetches are
  still cached for 900 s by `fetch(..., { next: { revalidate: 900 } })`, so the extra cost
  is render time, not TMDB calls. A hostile visitor can force uncached TMDB search calls by
  varying `q`. That is acceptable for a demo; see risk 2.
- **`request()` signature.** It is internal (not exported), so the only callers are in
  `lib/tmdb.ts`. Existing calls pass no params and behave as before. `lib/tmdb.test.ts`
  ("sends the key only from the server request" expects exactly 2 fetches for the home
  page) must stay green unchanged.
- **Mock-mode detail links.** A search result other than `mockDetail` links to a detail page
  that 404s in mock mode. Trending and popular cards already behave this way. Documented
  as a non-goal.
- **Reflected input.** The query is echoed into the empty-state message and the input's
  `defaultValue`. React escapes both. Nothing uses `dangerouslySetInnerHTML`.

## Decisions

1. **The query lives in the URL via a GET form on `/`,** not client state and not a
   `/search` route. This gives shareable addresses, Back support, no client JavaScript, and
   reuse of the existing missing-key handling.
   *Alternative:* a separate `/search` page. Rejected because the issue asks for search on
   the home page.
2. **Mock search filters a fixture catalog,** not a canned response per query. The
   "no match" and case-insensitive scenarios can then be tested in mock mode without a
   fixture per query.
3. **UI logic that can be unit-tested is pulled into `parseSearchQuery`.** The rendered
   page is checked by fetching it in mock mode rather than by a component test, because a
   component-testing library would mean editing `package.json`.

## The three decisions I am least confident about

1. **Mock matching is a substring match. TMDB's matching is not.** TMDB search tokenises
   the query and ranks fuzzily, so `lord rings` finds *The Lord of the Rings* live, but
   the mock's substring match finds nothing. Mock mode is the only mode the tests and the
   verifier exercise, so a test can pass where live behaviour differs, or the reverse.
   The spec scenarios only use full-title-substring queries (`inception`, `INCEPTION`, and
   a no-match string), where both agree. *Reviewer question:* is that enough, or should
   mock matching be token-based (every word appears in the title)?
2. **The home page stops being static.** Making `/` dynamic for every visitor, including
   those who never search, is the cost of keeping the query on the home URL. A
   `/search` route would keep `/` static and is a one-line change to the form's `action`.
   I chose the issue's literal wording ("a search box on the home page… shows the movies")
   over the caching win. There is also no rate limit on `q`. *Reviewer question:* is a
   dynamic `/` acceptable here?
3. **Slice 1 is a tracer bullet through the data boundary, not the UI.** The factory
   convention is a tracer slice that runs end to end against mocks, with later slices
   swapping in real behaviour. Here the UI cannot render search results until the
   load-bearing boundary exposes `searchMovies`. I also didn't want one slice mixing a
   `deep`-gated load-bearing change with ordinary UI work. So slice 1 lands the boundary
   with both the mock and live paths (live tested against a stubbed `fetch`, no network),
   and slice 2 lands the UI on top. The weaker point: the UI in slice 2 has no component
   test. Its evidence is the `parseSearchQuery` unit tests plus fetching `/?q=…` from a
   mock-mode server.

## Risks / Trade-offs

- [Mock and live matching diverge] → spec scenarios are limited to queries where they
  agree; flagged above for the reviewer.
- [Uncached TMDB calls driven by arbitrary `q`] → acceptable for a demo nobody depends on;
  revisit before any real deployment.
- [No component-level test for the results view] → `done_when` for slice 2 includes an
  HTTP check against a mock-mode server, which the verifier re-runs independently.
