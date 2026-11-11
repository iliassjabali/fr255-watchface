import { parseMonthFile } from "../domain/month.js";
import type { MonthLoad, MonthLoader } from "../domain/ports.js";

/** The part of the Workers Cache API that this adapter uses. */
export type CacheLike = {
  readonly match: (request: Request) => Promise<Response | undefined>;
  readonly put: (request: Request, response: Response) => Promise<void>;
};

export type HabousLoaderOptions = {
  readonly cache: CacheLike;
  readonly fetcher: (request: Request) => Promise<Response>;
};

const CACHE_SECONDS = 24 * 60 * 60;
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";

function monthUrl(year: number, month: number): string {
  return `https://www.habous.gov.ma/data/horaires-${year}-${String(month).padStart(2, "0")}.js`;
}

function toLoad(text: string): MonthLoad {
  const parsed = parseMonthFile(text);
  return parsed.ok ? { kind: "found", month: parsed.value } : { kind: "failed" };
}

async function fetchUpstream(url: string, fetcher: HabousLoaderOptions["fetcher"]) {
  try {
    return await fetcher(new Request(url, { headers: { "user-agent": USER_AGENT } }));
  } catch {
    return undefined;
  }
}

export function createHabousLoader({ cache, fetcher }: HabousLoaderOptions): MonthLoader {
  return async (year, month) => {
    const url = monthUrl(year, month);
    const key = new Request(url);

    const cached = await cache.match(key);
    if (cached) return toLoad(await cached.text());

    const upstream = await fetchUpstream(url, fetcher);
    if (!upstream) return { kind: "failed" };
    if (upstream.status === 404) return { kind: "missing" };
    if (!upstream.ok) return { kind: "failed" };

    const text = await upstream.text();
    const load = toLoad(text);
    if (load.kind === "found") {
      await cache.put(
        key,
        new Response(text, {
          headers: {
            "content-type": "application/javascript",
            "cache-control": `public, max-age=${CACHE_SECONDS}`,
          },
        }),
      );
    }
    return load;
  };
}
