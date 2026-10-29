# Proposal: search movies by title

## Why

A visitor who already knows which film they want has no way to find it. The home page
shows a fixed set of trending and popular titles, and the only other route is to guess a
TMDB id in the URL. Source: issue #3.

## What Changes

- A search box on the home page. Submitting a title shows the movies whose titles match,
  as cards that link to the existing detail page.
- A submitted search that matches nothing shows an empty-state message, not an error page.
- Submitting an empty or whitespace-only search shows the normal home page.
- The query lives in the page URL (`/?q=...`), so a search can be reloaded, shared and
  navigated with Back.
- Search works in mock mode (`TMDB_USE_MOCKS=true`) against committed fixtures, and the
  tests never touch the network.

## Success looks like

All four of these hold, checked in mock mode and by tests:

1. Searching `inception` shows a card titled *Inception*.
2. Searching a title with no match shows the empty-state message and returns HTTP 200.
3. Submitting an empty search shows the trending and popular sections, as before.
4. `npm test` passes with no network access, and a test proves the TMDB key is still sent
   only from the server request.

## What we are deliberately not doing

- **No search-as-you-type, suggestions, or autocomplete.** These need client-side state,
  debouncing and many more API calls. Submit-to-search covers the stated need.
- **No pagination.** Only TMDB's first page of results (up to 20) is shown. Users who don't
  see their film can type a more specific title.
- **No filters** (year, genre, adult content, language). TMDB's default `include_adult=false`
  applies.
- **No search outside the home page**, and no separate `/search` route.
- **No new mock detail pages.** In mock mode, only the one film that already has a detail
  fixture opens a detail page. Clicking any other result, including *Inception*, shows the
  existing not-found page. This is how mock mode already behaves for trending and popular
  cards.
- **No new dependencies.** `package.json` is load-bearing, and this feature does not need
  one.

Should this exist at all? Yes. Without it the app has no way to reach a specific film, and
the change is small. The cost is one more call path through the load-bearing TMDB boundary.

## Capabilities

### New Capabilities

- `movie-search`: finding movies by title from the home page, including the empty-query,
  no-results and mock-mode behaviour.

### Modified Capabilities

None. `openspec/specs/` has no existing capabilities.

## Impact

- `lib/tmdb.ts` (**load-bearing**) gains one exported search function and one TMDB call
  path. The API key handling does not change.
- The home page becomes dynamic per request when a query is present.
- No new dependencies, environment variables or routes.
