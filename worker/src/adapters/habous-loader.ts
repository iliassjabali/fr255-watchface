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

// Habous publishes a month one time. 32 days cover a file that the Worker gets on
// the last day of the month before (for the row of tomorrow) to the end of its month.
const CACHE_SECONDS = 32 * 24 * 60 * 60;
const FALLBACK_SECONDS = 62 * 24 * 60 * 60;
const MISSING_SECONDS = 60 * 60;
const FAILED_SECONDS = 10 * 60;
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

type Marker = "missing" | "failed";

const MARKER_SECONDS: Readonly<Record<Marker, number>> = { missing: MISSING_SECONDS, failed: FAILED_SECONDS };

function cached(body: string, contentType: string, seconds: number): Response {
  return new Response(body, {
    headers: { "content-type": contentType, "cache-control": `public, max-age=${seconds}` },
  });
}

export function createHabousLoader({ cache, fetcher }: HabousLoaderOptions): MonthLoader {
  return async (year, month) => {
    const url = monthUrl(year, month);
    const key = new Request(url);
    const fallbackKey = new Request(`${url}?copy=fallback`);
    const markerKey = new Request(`${url}?copy=marker`);

    const mark = (marker: Marker) => cache.put(markerKey, cached(marker, "text/plain", MARKER_SECONDS[marker]));

    /** The last good file, for the time when Habous fails or blocks the Worker. */
    const fallback = async (): Promise<MonthLoad> => {
      const copy = await cache.match(fallbackKey);
      return copy ? toLoad(await copy.text()) : { kind: "failed" };
    };

    const missing = async (): Promise<MonthLoad> => {
      await mark("missing");
      return { kind: "missing" };
    };

    const failed = async (): Promise<MonthLoad> => {
      await mark("failed");
      return fallback();
    };

    const fresh = await cache.match(key);
    if (fresh) return toLoad(await fresh.text());

    const marker = await cache.match(markerKey);
    if (marker) return (await marker.text()) === "missing" ? { kind: "missing" } : fallback();

    const upstream = await fetchUpstream(url, fetcher);
    if (!upstream) return failed();
    if (upstream.status === 404) return missing();
    if (!upstream.ok) return failed();

    const text = await upstream.text();
    const load = toLoad(text);
    if (load.kind !== "found") return failed();

    await cache.put(key, cached(text, "application/javascript", CACHE_SECONDS));
    await cache.put(fallbackKey, cached(text, "application/javascript", FALLBACK_SECONDS));
    return load;
  };
}
