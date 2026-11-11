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

  it("stores the file in the cache for 24 hours and serves the second call from it", async () => {
    const cache = fakeCache();
    const fetcher = fakeFetch(november);
    const loader = createHabousLoader({ cache, fetcher });
    await loader(2026, 11);
    const second = await loader(2026, 11);
    expect(second.kind).toBe("found");
    expect(fetcher.calls).toHaveLength(1);
    const stored = cache.store.get("https://www.habous.gov.ma/data/horaires-2026-11.js");
    expect(stored?.headers.get("cache-control")).toBe("public, max-age=86400");
  });

  it("reports a 404 as missing and does not cache it", async () => {
    const cache = fakeCache();
    const fetcher = fakeFetch(() => new Response("not found", { status: 404 }));
    const load = await createHabousLoader({ cache, fetcher })(2026, 12);
    expect(load.kind).toBe("missing");
    expect(cache.store.size).toBe(0);
  });

  it("reports other statuses, network errors and unparsable bodies as failed", async () => {
    const cache = fakeCache();
    const failing = [
      () => new Response("boom", { status: 500 }),
      () => {
        throw new Error("network down");
      },
      () => new Response("<html>hello</html>", { status: 200 }),
    ];
    for (const handler of failing) {
      const load = await createHabousLoader({ cache, fetcher: fakeFetch(handler) })(2026, 11);
      expect(load.kind).toBe("failed");
    }
    expect(cache.store.size).toBe(0);
  });
});
