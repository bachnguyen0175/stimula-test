# Tasks

## 1. Search through the TMDB boundary
> done_when: lib/tmdb-search.test.ts passes, proving searchMovies finds "Inception" for "inception" and "INCEPTION" in mock mode with fetch stubbed to throw, returns [] for "zzzz-no-such-film" and for a blank query without calling fetch, calls /search/movie with the query and api_key set as URL params in live mode, and throws MissingTmdbKeyError without a key; lib/tmdb.test.ts passes unchanged
> files_expected: lib/tmdb.ts, lib/tmdb-fixtures.ts, lib/tmdb-search.test.ts
> load_bearing: true
> gate_level: deep
- [ ] 1.1 Add an Inception (id 27205) search-only fixture to lib/tmdb-fixtures.ts and verify the existing lib/tmdb.test.ts still passes
- [ ] 1.2 Let request() accept optional query params set through URLSearchParams, and verify existing calls produce identical URLs (lib/tmdb.test.ts stays green)
- [ ] 1.3 Add searchMovies(query) with the mock path (case-insensitive title substring over the deduplicated fixture catalog) and the live path (/search/movie), and verify with the new mock-mode tests in lib/tmdb-search.test.ts
- [ ] 1.4 Cover the live path with a stubbed fetch (URL path, encoded query, api_key) and the missing-key error in lib/tmdb-search.test.ts, and verify that npm test makes no network calls

## 2. Search box and results on the home page
> done_when: lib/search-query.test.ts passes for "  inception " -> "inception", "" / "   " / undefined -> null, and an array -> its first trimmed entry; and with TMDB_USE_MOCKS=true a production server returns 200 for /?q=inception containing "Inception", 200 for /?q=zzzz-no-such-film containing the no-match message, and /?q=%20 containing both "Trending now" and "Popular on TMDB"
> files_expected: lib/search-query.ts, lib/search-query.test.ts, components/search-form.tsx, app/page.tsx, app/globals.css
> load_bearing: false
> gate_level: full
- [ ] 2.1 Add parseSearchQuery(raw) in lib/search-query.ts and verify it with lib/search-query.test.ts
- [ ] 2.2 Add a server-rendered GET search form (labelled input named q, defaultValue from the current query) in components/search-form.tsx and verify npm run typecheck and npm run lint pass
- [ ] 2.3 Branch app/page.tsx on the parsed query: results grid, no-match empty state, or the existing home sections, with MissingTmdbKeyError still showing SetupNotice, and verify with the mock-mode HTTP checks in done_when
- [ ] 2.4 Style the form and the empty state in app/globals.css, and verify by viewing the search and no-match states at desktop and phone widths in mock mode
