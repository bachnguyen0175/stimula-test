## Purpose

Let a visitor find a specific movie by typing part of its title on the home page, without
exposing the TMDB credential to the browser and without needing the network in tests.

## ADDED Requirements

### Requirement: Search box on the home page

The home page SHALL show a labelled search box that submits a title query. A submitted
query SHALL be kept in the page address, so reloading or sharing that address shows the
same search.

#### Scenario: Visitor submits a title

- **WHEN** a visitor types `inception` into the home page search box and submits
- **THEN** the page address carries the query `inception`
- **AND** the search box still shows `inception`

#### Scenario: Shared search address

- **WHEN** a visitor opens the home page address with the query `inception` already in it
- **THEN** the page shows the results for `inception` without the visitor typing anything

### Requirement: Matching results are shown as movie cards

When a non-empty query is submitted, the home page SHALL show the movies whose titles match
the query, each as a card that links to that movie's detail page, in place of the trending
and popular sections.

#### Scenario: Known title matches

- **WHEN** a visitor searches `inception`
- **THEN** the results include a card titled `Inception`
- **AND** that card links to the detail page for that movie

#### Scenario: Matching ignores letter case

- **WHEN** a visitor searches `INCEPTION`
- **THEN** the results include a card titled `Inception`

### Requirement: No-match searches show an empty state

A search that matches no movies SHALL show a message saying nothing matched the query. It
SHALL NOT show an error page and SHALL respond successfully.

#### Scenario: Nothing matches

- **WHEN** a visitor searches `zzzz-no-such-film`
- **THEN** the page shows a message stating that no movies matched `zzzz-no-such-film`
- **AND** the response is successful, not an error

### Requirement: Empty search returns to the home page

A submitted query that is empty or contains only whitespace SHALL be treated as no search:
the home page SHALL show its normal trending and popular sections.

#### Scenario: Empty submit

- **WHEN** a visitor submits the search box with nothing typed
- **THEN** the page shows the trending and popular sections

#### Scenario: Whitespace-only submit

- **WHEN** a visitor submits the search box containing only spaces
- **THEN** the page shows the trending and popular sections

### Requirement: Search works in mock mode without network

With mock mode enabled, search SHALL answer from committed fixture data, need no TMDB
credential, and make no network request.

#### Scenario: Mock-mode search finds a fixture title

- **WHEN** mock mode is enabled, no TMDB credential is set, and a visitor searches `inception`
- **THEN** the results include a card titled `Inception`
- **AND** no network request is made

#### Scenario: Mock-mode search with no match

- **WHEN** mock mode is enabled and a visitor searches `zzzz-no-such-film`
- **THEN** the page shows the no-match message

### Requirement: TMDB credential stays on the server

Search requests to TMDB SHALL be made only from the server, and the TMDB credential SHALL
NOT appear in anything sent to the browser, including the page address and page content.

#### Scenario: Live search request carries the credential server-side only

- **WHEN** mock mode is off, a credential is configured, and a visitor searches `inception`
- **THEN** the server's request to TMDB's movie search carries the credential and the query
- **AND** the page address and rendered page do not contain the credential

#### Scenario: Missing credential in live mode

- **WHEN** mock mode is off, no credential is configured, and a visitor searches
- **THEN** the page shows the existing setup notice instead of an error page
