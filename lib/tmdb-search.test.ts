import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const failingFetch = () => vi.fn().mockRejectedValue(new Error("network is not allowed in tests"));

describe("searchMovies", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it.each(["inception", "INCEPTION", " inception "])("finds Inception in mock mode for %j", async (query) => {
    vi.stubEnv("TMDB_USE_MOCKS", "true");
    const fetchMock = failingFetch();
    vi.stubGlobal("fetch", fetchMock);
    const { searchMovies } = await import("./tmdb");
    const results = await searchMovies(query);
    expect(results.map((movie) => movie.title)).toContain("Inception");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("returns no results in mock mode when nothing matches", async () => {
    vi.stubEnv("TMDB_USE_MOCKS", "true");
    vi.stubGlobal("fetch", failingFetch());
    const { searchMovies } = await import("./tmdb");
    expect(await searchMovies("zzzz-no-such-film")).toEqual([]);
  });

  it("does not repeat a fixture that appears in more than one mock list", async () => {
    vi.stubEnv("TMDB_USE_MOCKS", "true");
    vi.stubGlobal("fetch", failingFetch());
    const { searchMovies } = await import("./tmdb");
    const results = await searchMovies("fight club");
    expect(results.filter((movie) => movie.id === 550)).toHaveLength(1);
  });

  it.each(["", "   "])("returns [] for the blank query %j without calling fetch", async (query) => {
    vi.stubEnv("TMDB_USE_MOCKS", "false");
    vi.stubEnv("TMDB_API_KEY", "test-key");
    const fetchMock = failingFetch();
    vi.stubGlobal("fetch", fetchMock);
    const { searchMovies } = await import("./tmdb");
    expect(await searchMovies(query)).toEqual([]);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("calls TMDB movie search live with the query and exactly one api_key", async () => {
    vi.stubEnv("TMDB_USE_MOCKS", "false");
    vi.stubEnv("TMDB_API_KEY", "test-key");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ results: [{ id: 27205, title: "Inception" }] }),
    });
    vi.stubGlobal("fetch", fetchMock);
    const { searchMovies } = await import("./tmdb");

    const results = await searchMovies("inception");

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const url = new URL(String(fetchMock.mock.calls[0][0]));
    expect(url.pathname).toBe("/3/search/movie");
    expect(url.searchParams.get("query")).toBe("inception");
    expect(url.searchParams.getAll("api_key")).toEqual(["test-key"]);
    expect(results).toEqual([expect.objectContaining({ id: 27205, title: "Inception" })]);
  });

  it("throws MissingTmdbKeyError in live mode without a key", async () => {
    vi.stubEnv("TMDB_USE_MOCKS", "false");
    vi.stubEnv("TMDB_API_KEY", "");
    vi.stubGlobal("fetch", failingFetch());
    const { searchMovies, MissingTmdbKeyError } = await import("./tmdb");
    await expect(searchMovies("inception")).rejects.toBeInstanceOf(MissingTmdbKeyError);
  });
});
