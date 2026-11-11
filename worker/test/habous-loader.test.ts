import { describe, expect, it } from "vitest";
import { createHabousLoader, type CacheLike } from "../src/adapters/habous-loader.js";
import { fixture } from "./helpers.js";

function fakeCache(): CacheLike & { readonly store: Map<string, Response> } {
  const store = new Map<string, Response>();
  return {
    store,
    match: async (request) => store.get(request.url)?.clone(),
    put: async (request, response) => {
      store.set(request.url, response);
    },
  };
}

function fakeFetch(handler: (url: string) => Response | Promise<Response>) {
  const calls: { url: string; userAgent: string | null }[] = [];
  const fn = async (input: Request): Promise<Response> => {
    calls.push({ url: input.url, userAgent: input.headers.get("user-agent") });
    return handler(input.url);
  };
  return Object.assign(fn, { calls });
}

const NOVEMBER_URL = "https://www.habous.gov.ma/data/horaires-2026-11.js";
const DECEMBER_URL = "https://www.habous.gov.ma/data/horaires-2026-12.js";

const november = () => new Response(fixture("horaires-2026-11.js"), { status: 200 });

describe("createHabousLoader", () => {
  it("fetches the month file with a browser-like user agent and parses it", async () => {
    const fetcher = fakeFetch(november);
    const load = await createHabousLoader({ cache: fakeCache(), fetcher })(2026, 11);
    expect(load.kind).toBe("found");
    expect(fetcher.calls).toEqual([
      {
        url: "https://www.habous.gov.ma/data/horaires-2026-11.js",
        userAgent: expect.stringContaining("Mozilla/5.0"),
      },
    ]);
  });

  it("pads single digit months in the URL", async () => {
    const fetcher = fakeFetch(() => new Response("", { status: 404 }));
    await createHabousLoader({ cache: fakeCache(), fetcher })(2026, 3);
    expect(fetcher.calls[0]?.url).toBe("https://www.habous.gov.ma/data/horaires-2026-03.js");
  });

  it("stores the file in the cache for 32 days and serves the second call from it", async () => {
    const cache = fakeCache();
    const fetcher = fakeFetch(november);
    const loader = createHabousLoader({ cache, fetcher });
    await loader(2026, 11);
    const second = await loader(2026, 11);
    expect(second.kind).toBe("found");
    expect(fetcher.calls).toHaveLength(1);
    const stored = cache.store.get("https://www.habous.gov.ma/data/horaires-2026-11.js");
    expect(stored?.headers.get("cache-control")).toBe("public, max-age=2764800");
  });

  it("reports a 404 as missing and does not ask Habous again for 1 hour", async () => {
    const cache = fakeCache();
    const fetcher = fakeFetch(() => new Response("not found", { status: 404 }));
    const loader = createHabousLoader({ cache, fetcher });
    const first = await loader(2026, 12);
    const second = await loader(2026, 12);
    expect(first.kind).toBe("missing");
    expect(second.kind).toBe("missing");
    expect(fetcher.calls).toHaveLength(1);
    const marker = cache.store.get(DECEMBER_URL + "?copy=marker");
    expect(marker?.headers.get("cache-control")).toBe("public, max-age=3600");
  });

  it("keeps a fallback copy of a good file for 62 days", async () => {
    const cache = fakeCache();
    await createHabousLoader({ cache, fetcher: fakeFetch(november) })(2026, 11);
    const fallback = cache.store.get(NOVEMBER_URL + "?copy=fallback");
    expect(fallback?.headers.get("cache-control")).toBe("public, max-age=5356800");
  });

  it("serves the fallback copy when the month copy is gone and Habous fails, with one call for 10 minutes", async () => {
    const cache = fakeCache();
    await createHabousLoader({ cache, fetcher: fakeFetch(november) })(2026, 11);
    cache.store.delete(NOVEMBER_URL);

    const fetcher = fakeFetch(() => new Response("blocked", { status: 429 }));
    const loader = createHabousLoader({ cache, fetcher });
    const first = await loader(2026, 11);
    const second = await loader(2026, 11);

    expect(first.kind).toBe("found");
    expect(second.kind).toBe("found");
    expect(fetcher.calls).toHaveLength(1);
  });

  it("asks Habous again when the failure marker ended, and refreshes the copies", async () => {
    const cache = fakeCache();
    await createHabousLoader({ cache, fetcher: fakeFetch(november) })(2026, 11);
    cache.store.delete(NOVEMBER_URL);
    await createHabousLoader({ cache, fetcher: fakeFetch(() => new Response("boom", { status: 500 })) })(2026, 11);
    cache.store.delete(NOVEMBER_URL + "?copy=marker");

    const fetcher = fakeFetch(november);
    const load = await createHabousLoader({ cache, fetcher })(2026, 11);

    expect(load.kind).toBe("found");
    expect(fetcher.calls).toHaveLength(1);
    expect(cache.store.has(NOVEMBER_URL)).toBe(true);
  });

  const failures: readonly (readonly [string, () => Response])[] = [
    ["a 500 status", () => new Response("boom", { status: 500 })],
    [
      "a network error",
      () => {
        throw new Error("network down");
      },
    ],
    ["a body that does not parse", () => new Response("<html>hello</html>", { status: 200 })],
  ];

  it.each(failures)("reports %s as failed and does not ask Habous again for 10 minutes", async (_name, handler) => {
    const cache = fakeCache();
    const fetcher = fakeFetch(handler);
    const loader = createHabousLoader({ cache, fetcher });
    const first = await loader(2026, 11);
    const second = await loader(2026, 11);
    expect(first.kind).toBe("failed");
    expect(second.kind).toBe("failed");
    expect(fetcher.calls).toHaveLength(1);
    const marker = cache.store.get(NOVEMBER_URL + "?copy=marker");
    expect(marker?.headers.get("cache-control")).toBe("public, max-age=600");
    expect(cache.store.has(NOVEMBER_URL)).toBe(false);
  });
});
