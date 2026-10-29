# Tasks

## 1. Search through the TMDB boundary
> done_when: npx vitest run lib/tmdb-search.test.ts lib/tmdb.test.ts passes with lib/tmdb.test.ts unchanged, and lib/tmdb-search.test.ts proves that searchMovies (a) in mock mode with fetch stubbed to throw returns a result titled "Inception" for "inception", "INCEPTION" and " inception ", and [] for "zzzz-no-such-film"; (b) returns [] for "" and "   " without calling fetch; (c) in live mode calls a URL whose path is /3/search/movie, whose query param equals the input, and which has exactly one api_key param equal to the configured key; (d) throws MissingTmdbKeyError in live mode without a key
> files_expected: lib/tmdb.ts, lib/tmdb-fixtures.ts, lib/tmdb-search.test.ts
> load_bearing: true
> gate_level: deep
- [ ] 1.1 Add an Inception (id 27205) search-only fixture export to lib/tmdb-fixtures.ts, leaving mockTrending, mockPopular and mockDetail unchanged, and verify lib/tmdb.test.ts still passes
- [ ] 1.2 Let request() take optional query params, applied with URLSearchParams before api_key and language so they cannot overwrite them, and verify existing calls build identical URLs (lib/tmdb.test.ts stays green)
- [ ] 1.3 Add searchMovies(query), which trims its own input, returns [] for a blank query without a request, matches mock titles case-insensitively by substring over the deduplicated fixture catalog, and calls /search/movie live; verify with the mock-mode cases in lib/tmdb-search.test.ts (mock server-only with vi.mock and reset modules between tests, as lib/tmdb.test.ts does)
- [ ] 1.4 Cover the live path with a stubbed fetch (path, query param, exactly one api_key) and the missing-key error in lib/tmdb-search.test.ts, and verify npm test makes no network calls

## 2. Search box and results on the home page
> done_when: npx vitest run lib/search-query.test.ts passes for "  inception " -> "inception", "" / "   " / undefined -> null, ["  a ", "b"] -> "a", and a 150-character query -> its first 100 characters trimmed; and after TMDB_USE_MOCKS=true npm run build, with TMDB_USE_MOCKS=true npx next start -p 3123 and no TMDB_API_KEY, curl -s -o /dev/null -w '%{http_code}' returns 200 for /?q=inception, /?q=zzzz-no-such-film and /?q=%20, the /?q=inception body contains href="/movies/27205", the /?q=zzzz-no-such-film body contains "No movies matched" and does not contain href="/movies/, and the /?q=%20 body contains both "Trending now" and "Popular on TMDB"
> files_expected: lib/search-query.ts, lib/search-query.test.ts, components/search-form.tsx, app/page.tsx, app/globals.css
> load_bearing: false
> gate_level: full
- [ ] 2.1 Confirm slice 1 is merged (git grep -n "export async function searchMovies" origin/main -- lib/tmdb.ts prints a match) before starting; if not, stop and move this issue to factory:wait-to-implement naming slice 1
- [ ] 2.2 Add parseSearchQuery(raw) with MAX_QUERY_LENGTH = 100 in lib/search-query.ts and verify it with lib/search-query.test.ts
- [ ] 2.3 Add a server-rendered GET search form (action "/", labelled input named q, defaultValue from the current query) in components/search-form.tsx and verify npm run typecheck and npm run lint pass
- [ ] 2.4 Branch app/page.tsx on the parsed query: form below the hero plus the existing sections, or form plus results grid, or form plus the "No movies matched" empty state; keep MissingTmdbKeyError showing SetupNotice on both paths; delete the now-dead revalidate export; verify with the HTTP checks in done_when
- [ ] 2.5 Style the form and the empty state in app/globals.css, and have a human view the search and no-match states at desktop and phone widths in mock mode (not machine-checked)
