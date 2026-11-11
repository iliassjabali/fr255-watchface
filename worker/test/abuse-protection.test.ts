import { describe, expect, it } from "vitest";
import { handlePrayers, type Dependencies } from "../src/handler.js";
import { parseMonthFile } from "../src/domain/month.js";
import type { MonthLoader, RateLimiter } from "../src/domain/ports.js";
import type { City } from "../src/domain/nearest-city.js";
import { fixture } from "./helpers.js";

const cities: readonly City[] = [{ id: 58, lat: 33.5731, lon: -7.5898 }];

function novemberLoader(): MonthLoader & { readonly calls: number[] } {
  const parsed = parseMonthFile(fixture("horaires-2026-11.js"));
  if (!parsed.ok) throw new Error(parsed.error);
  const month = parsed.value;
  const calls: number[] = [];
  const loader: MonthLoader = async (_year, monthNumber) => {
    calls.push(monthNumber);
    return monthNumber === 11 ? { kind: "found", month } : { kind: "missing" };
  };
  return Object.assign(loader, { calls });
}

function recordingLimiter(allowed: boolean): RateLimiter & { readonly keys: string[] } {
  const keys: string[] = [];
  return {
    keys,
    allow: async (key) => {
      keys.push(key);
      return allowed;
    },
  };
}

function setup(rateLimiter: RateLimiter = { allow: async () => true }) {
  const loadMonth = novemberLoader();
  const dependencies: Dependencies = {
    cities,
    loadMonth,
    rateLimiter,
    now: () => new Date("2026-11-11T08:00:00Z"),
  };
  return { loadMonth, dependencies };
}

async function get(path: string, dependencies: Dependencies, headers: Record<string, string> = {}) {
  const response = await handlePrayers(new Request(`http://localhost${path}`, { headers }), dependencies);
  return { response, body: (await response.json()) as unknown };
}

const VALID = "/prayers?lat=33.57&lon=-7.59&date=2026-11-11";

describe("rate limiting", () => {
  it("answers 429 with Retry-After when the limiter denies", async () => {
    const { loadMonth, dependencies } = setup(recordingLimiter(false));
    const { response, body } = await get(VALID, dependencies);
    expect(response.status).toBe(429);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(response.headers.get("retry-after")).toBe("60");
    expect(body).toEqual({ error: "too many requests" });
    expect(loadMonth.calls).toEqual([]);
  });

  it("uses the CF-Connecting-IP header as the key", async () => {
    const limiter = recordingLimiter(true);
    await get(VALID, setup(limiter).dependencies, { "CF-Connecting-IP": "203.0.113.7" });
    expect(limiter.keys).toEqual(["203.0.113.7"]);
  });

  it("uses the key unknown when the header is missing", async () => {
    const limiter = recordingLimiter(true);
    await get(VALID, setup(limiter).dependencies);
    expect(limiter.keys).toEqual(["unknown"]);
  });

  it("limits unknown paths too", async () => {
    const limiter = recordingLimiter(false);
    const { response } = await get("/other", setup(limiter).dependencies);
    expect(response.status).toBe(429);
    expect(limiter.keys).toHaveLength(1);
  });

  it("limits non-GET requests too", async () => {
    const limiter = recordingLimiter(false);
    const response = await handlePrayers(
      new Request(`http://localhost${VALID}`, { method: "POST" }),
      setup(limiter).dependencies,
    );
    expect(response.status).toBe(429);
  });

  it("keeps the exact Casablanca answer when the limiter allows", async () => {
    const { response, body } = await get(VALID, setup().dependencies);
    expect(response.status).toBe(200);
    expect(body).toEqual({
      city: 58,
      date: "2026-11-11",
      today: [328, 415, 740, 910, 1055, 1131],
      tomorrow: [328, 416, 740, 909, 1054, 1131],
    });
  });

  it("keeps the 404 for an unknown path", async () => {
    const { response, body } = await get("/other", setup().dependencies);
    expect(response.status).toBe(404);
    expect(body).toEqual({ error: "not found" });
  });
});

describe("strict validation", () => {
  it("rejects an unknown parameter", async () => {
    const { loadMonth, dependencies } = setup();
    const { response, body } = await get(`${VALID}&debug=1`, dependencies);
    expect(response.status).toBe(400);
    expect(body).toEqual({ error: "unknown parameter" });
    expect(loadMonth.calls).toEqual([]);
  });

  it("rejects a repeated parameter", async () => {
    const { response, body } = await get(
      "/prayers?lat=33.57&lat=34.02&lon=-7.59",
      setup().dependencies,
    );
    expect(response.status).toBe(400);
    expect(body).toEqual({ error: "duplicate parameter" });
  });

  it.each([
    ["exponent", "lat=1e2&lon=-7.59"],
    ["hex", "lat=0x10&lon=-7.59"],
    ["empty", "lat=&lon=-7.59"],
    ["NaN", "lat=NaN&lon=-7.59"],
    ["Infinity", "lat=Infinity&lon=-7.59"],
    ["space", "lat=%2033&lon=-7.59"],
    ["plus sign", "lat=%2B33&lon=-7.59"],
    ["too many decimals", "lat=33.1234567&lon=-7.59"],
    ["four integer digits", "lat=1000&lon=-7.59"],
    ["leading dot", "lat=.5&lon=-7.59"],
    ["trailing dot", "lat=33.&lon=-7.59"],
    ["lon exponent", "lat=33.57&lon=1e1"],
    ["lon out of range", "lat=33.57&lon=180.5"],
    ["lat out of range", "lat=90.5&lon=-7.59"],
  ])("rejects a %s coordinate with 400", async (_name, query) => {
    const { loadMonth, dependencies } = setup();
    const { response, body } = await get(`/prayers?${query}`, dependencies);
    expect(response.status).toBe(400);
    expect(body).toEqual({ error: expect.any(String) });
    expect(loadMonth.calls).toEqual([]);
  });

  it("accepts the limits of the decimal pattern", async () => {
    const { response } = await get("/prayers?lat=33.573100&lon=-7.589800&date=2026-11-11", setup().dependencies);
    expect(response.status).toBe(200);
  });

  it("answers 414 for a URL longer than 200 characters", async () => {
    const { loadMonth, dependencies } = setup();
    const longUrl = `${VALID}&date=${"x".repeat(200)}`;
    const { response, body } = await get(longUrl, dependencies);
    expect(response.status).toBe(414);
    expect(body).toEqual({ error: "uri too long" });
    expect(loadMonth.calls).toEqual([]);
  });

  it("accepts a URL of exactly 200 characters and rejects 201", async () => {
    const prefix = "http://localhost/other?";
    const atLimit = prefix + "a".repeat(200 - prefix.length);
    expect(atLimit.length).toBe(200);
    const ok = await handlePrayers(new Request(atLimit), setup().dependencies);
    expect(ok.status).toBe(404);
    const tooLong = await handlePrayers(new Request(`${atLimit}a`), setup().dependencies);
    expect(tooLong.status).toBe(414);
  });

  it("keeps 405 for a non-GET request", async () => {
    const response = await handlePrayers(
      new Request(`http://localhost${VALID}`, { method: "POST" }),
      setup().dependencies,
    );
    expect(response.status).toBe(405);
  });
});
