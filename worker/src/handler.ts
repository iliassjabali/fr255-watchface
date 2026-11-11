import { formatIsoDate, nextDay, parseIsoDate, utcDateOf, type CalendarDate } from "./domain/calendar-date.js";
import { selectDay, type DayRow, type MonthFile } from "./domain/month.js";
import { nearestCityWithinLimit, type City } from "./domain/nearest-city.js";
import type { MonthLoader, RateLimiter } from "./domain/ports.js";
import { toUtcMinutes } from "./domain/time.js";

export type Dependencies = {
  readonly cities: readonly City[];
  readonly loadMonth: MonthLoader;
  readonly rateLimiter: RateLimiter;
  readonly now: () => Date;
};

type Query = { readonly lat: number; readonly lon: number; readonly date: CalendarDate };
type Parsed = { readonly ok: true; readonly query: Query } | { readonly ok: false; readonly error: string };

const JSON_HEADERS = { "content-type": "application/json" } as const;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

const MAX_URL_LENGTH = 200;
const ALLOWED_PARAMETERS: readonly string[] = ["lat", "lon", "date"];
const DECIMAL = /^-?\d{1,3}(\.\d{1,6})?$/;

function parseCoordinate(raw: string | null, name: string, limit: number): number | string {
  if (raw === null || raw === "") return `${name} is required`;
  if (!DECIMAL.test(raw)) return `${name} is invalid`;
  const value = Number(raw);
  return Math.abs(value) > limit ? `${name} is invalid` : value;
}

function checkParameterNames(params: URLSearchParams): string | undefined {
  const seen = new Set<string>();
  for (const name of params.keys()) {
    if (!ALLOWED_PARAMETERS.includes(name)) return "unknown parameter";
    if (seen.has(name)) return "duplicate parameter";
    seen.add(name);
  }
  return undefined;
}

function parseQuery(params: URLSearchParams, now: Date): Parsed {
  const nameError = checkParameterNames(params);
  if (nameError) return { ok: false, error: nameError };
  const lat = parseCoordinate(params.get("lat"), "lat", 90);
  if (typeof lat === "string") return { ok: false, error: lat };
  const lon = parseCoordinate(params.get("lon"), "lon", 180);
  if (typeof lon === "string") return { ok: false, error: lon };
  const rawDate = params.get("date");
  if (rawDate === null) return { ok: true, query: { lat, lon, date: utcDateOf(now) } };
  const date = parseIsoDate(rawDate);
  if (!date) return { ok: false, error: "date is invalid" };
  return { ok: true, query: { lat, lon, date } };
}

function toUtcRow(row: DayRow, fuseau: string): number[] | undefined {
  const minutes = row.map((time) => toUtcMinutes(time, fuseau));
  return minutes.every((value): value is number => value !== undefined) ? minutes : undefined;
}

async function tomorrowRow(
  date: CalendarDate,
  cityId: number,
  current: MonthFile,
  loadMonth: MonthLoader,
): Promise<number[] | undefined> {
  const next = nextDay(date);
  const sameMonth = next.month === date.month && next.year === date.year;
  const load = sameMonth ? { kind: "found", month: current } as const : await loadMonth(next.year, next.month);
  if (load.kind !== "found") return undefined;
  const row = selectDay(load.month, cityId, next.day);
  return row && toUtcRow(row, load.month.fuseau);
}

export async function handlePrayers(request: Request, deps: Dependencies): Promise<Response> {
  const key = request.headers.get("cf-connecting-ip") ?? "unknown";
  if (!(await deps.rateLimiter.allow(key))) {
    return new Response(JSON.stringify({ error: "too many requests" }), {
      status: 429,
      headers: { ...JSON_HEADERS, "retry-after": "60" },
    });
  }
  if (request.url.length > MAX_URL_LENGTH) return json(414, { error: "uri too long" });

  const url = new URL(request.url);
  if (url.pathname !== "/prayers") return json(404, { error: "not found" });
  if (request.method !== "GET") return json(405, { error: "method not allowed" });

  const parsed = parseQuery(url.searchParams, deps.now());
  if (!parsed.ok) return json(400, { error: parsed.error });
  const { lat, lon, date } = parsed.query;

  const city = nearestCityWithinLimit(deps.cities, lat, lon);
  if (!city) return json(404, { error: "no city near" });

  const load = await deps.loadMonth(date.year, date.month);
  if (load.kind !== "found") return json(502, { error: "prayer times unavailable" });

  const row = selectDay(load.month, city.id, date.day);
  const today = row && toUtcRow(row, load.month.fuseau);
  if (!today) return json(502, { error: "prayer times unreadable" });

  const tomorrow = await tomorrowRow(date, city.id, load.month, deps.loadMonth);
  return json(200, {
    city: city.id,
    date: formatIsoDate(date),
    today,
    ...(tomorrow ? { tomorrow } : {}),
  });
}
