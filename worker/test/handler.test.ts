import { describe, expect, it } from "vitest";
import { handlePrayers, type Dependencies } from "../src/handler.js";
import { parseMonthFile } from "../src/domain/month.js";
import type { MonthLoad, MonthLoader } from "../src/domain/ports.js";
import type { City } from "../src/domain/nearest-city.js";
import { fixture } from "./helpers.js";

const cities: readonly City[] = [
  { id: 1, lat: 34.0209, lon: -6.8416 },
  { id: 58, lat: 33.5731, lon: -7.5898 },
];

function fixtureLoad(name: string): MonthLoad {
  const parsed = parseMonthFile(fixture(name));
  if (!parsed.ok) throw new Error(parsed.error);
  return { kind: "found", month: parsed.value };
}

type FakeLoader = MonthLoader & { readonly calls: string[] };

function fakeLoader(months: Readonly<Record<string, MonthLoad>>): FakeLoader {
  const calls: string[] = [];
  const loader = async (year: number, month: number): Promise<MonthLoad> => {
    const key = `${year}-${String(month).padStart(2, "0")}`;
    calls.push(key);
    return months[key] ?? { kind: "missing" };
  };
  return Object.assign(loader, { calls });
}

function deps(loadMonth: MonthLoader): Dependencies {
  return {
    cities,
    loadMonth,
    rateLimiter: { allow: async () => true },
    now: () => new Date("2026-11-11T08:00:00Z"),
  };
}

const octAndNov = () =>
  fakeLoader({
    "2026-10": fixtureLoad("horaires-2026-10.js"),
    "2026-11": fixtureLoad("horaires-2026-11.js"),
  });

async function get(path: string, dependencies: Dependencies) {
  const response = await handlePrayers(new Request(`http://localhost${path}`), dependencies);
  return { response, body: (await response.json()) as unknown };
}

describe("handlePrayers", () => {
  it("returns today and tomorrow for Casablanca", async () => {
    const { response, body } = await get(
      "/prayers?lat=33.57&lon=-7.59&date=2026-11-11",
      deps(octAndNov()),
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(body).toEqual({
      city: 58,
      date: "2026-11-11",
      today: [328, 415, 740, 910, 1055, 1131],
      tomorrow: [328, 416, 740, 909, 1054, 1131],
    });
  });

  it("returns only the documented keys", async () => {
    const { body } = await get("/prayers?lat=34.02&lon=-6.84&date=2026-11-11", deps(octAndNov()));
    expect(Object.keys(body as object)).toEqual(["city", "date", "today", "tomorrow"]);
    expect((body as { city: number }).city).toBe(1);
  });

  it("uses today in UTC when no date is given", async () => {
    const { body } = await get("/prayers?lat=33.57&lon=-7.59", deps(octAndNov()));
    expect(body).toMatchObject({ date: "2026-11-11", today: [328, 415, 740, 910, 1055, 1131] });
  });

  it("serves the October data for an October date", async () => {
    const { body } = await get("/prayers?lat=33.57&lon=-7.59&date=2026-10-11", deps(octAndNov()));
    expect(body).toMatchObject({ today: [304, 389, 742, 933, 1086, 1160] });
  });

  it("loads only one month when tomorrow is in the same month", async () => {
    const loader = octAndNov();
    await get("/prayers?lat=33.57&lon=-7.59&date=2026-11-11", deps(loader));
    expect(loader.calls).toEqual(["2026-11"]);
  });

  it("takes tomorrow from November on 2026-10-31", async () => {
    const { body } = await get("/prayers?lat=33.57&lon=-7.59&date=2026-10-31", deps(octAndNov()));
    const november1 = await get("/prayers?lat=33.57&lon=-7.59&date=2026-11-01", deps(octAndNov()));
    const expected = (november1.body as { today: number[] }).today;
    expect(expected).toHaveLength(6);
    expect(body).toMatchObject({ date: "2026-10-31", tomorrow: expected });
    expect((body as { today: number[] }).today).not.toEqual(expected);
  });

  it("omits tomorrow on 2026-11-30 when December is missing", async () => {
    const { response, body } = await get(
      "/prayers?lat=33.57&lon=-7.59&date=2026-11-30",
      deps(octAndNov()),
    );
    expect(response.status).toBe(200);
    expect(body).not.toHaveProperty("tomorrow");
    expect(body).toHaveProperty("today");
  });

  it("omits tomorrow when the next month fails to load", async () => {
    const loader = fakeLoader({
      "2026-11": fixtureLoad("horaires-2026-11.js"),
      "2026-12": { kind: "failed" },
    });
    const { response, body } = await get("/prayers?lat=33.57&lon=-7.59&date=2026-11-30", deps(loader));
    expect(response.status).toBe(200);
    expect(body).not.toHaveProperty("tomorrow");
  });

  it.each([
    ["missing lat", "/prayers?lon=-7.59"],
    ["missing lon", "/prayers?lat=33.57"],
    ["empty lat", "/prayers?lat=&lon=-7.59"],
    ["non numeric lat", "/prayers?lat=abc&lon=-7.59"],
    ["lat too large", "/prayers?lat=91&lon=-7.59"],
    ["lon too large", "/prayers?lat=33&lon=181"],
    ["bad date format", "/prayers?lat=33&lon=-7&date=11-11-2026"],
    ["impossible date", "/prayers?lat=33&lon=-7&date=2026-02-30"],
  ])("answers 400 for %s", async (_name, path) => {
    const { response, body } = await get(path, deps(octAndNov()));
    expect(response.status).toBe(400);
    expect(body).toEqual({ error: expect.any(String) });
  });

  it("still serves a point about 20 km from the Casablanca coordinates", async () => {
    const { response, body } = await get(
      "/prayers?lat=33.7531&lon=-7.5898&date=2026-11-11",
      deps(octAndNov()),
    );
    expect(response.status).toBe(200);
    expect(body).toMatchObject({ city: 58 });
  });

  it("answers 404 when no city is within 25 km", async () => {
    const loader = octAndNov();
    const { response, body } = await get("/prayers?lat=29.00&lon=-4.00&date=2026-11-11", deps(loader));
    expect(response.status).toBe(404);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(body).toEqual({ error: "no city near" });
    expect(loader.calls).toEqual([]);
  });

  it("answers 404 for an unknown path", async () => {
    const { response } = await get("/other?lat=33&lon=-7", deps(octAndNov()));
    expect(response.status).toBe(404);
  });

  it("answers 502 when the requested month is missing", async () => {
    const { response, body } = await get(
      "/prayers?lat=33.57&lon=-7.59&date=2026-12-05",
      deps(octAndNov()),
    );
    expect(response.status).toBe(502);
    expect(body).toEqual({ error: expect.any(String) });
  });

  it("answers 502 when the requested month fails to load", async () => {
    const loader = fakeLoader({ "2026-11": { kind: "failed" } });
    const { response } = await get("/prayers?lat=33.57&lon=-7.59&date=2026-11-11", deps(loader));
    expect(response.status).toBe(502);
  });

  it("answers 502 for an unknown fuseau", async () => {
    const november = fixtureLoad("horaires-2026-11.js");
    if (november.kind !== "found") throw new Error("fixture");
    const loader = fakeLoader({
      "2026-11": { kind: "found", month: { ...november.month, fuseau: "Mars/Olympus" } },
    });
    const { response } = await get("/prayers?lat=33.57&lon=-7.59&date=2026-11-11", deps(loader));
    expect(response.status).toBe(502);
  });

  it("answers 502 when the city is absent from the month file", async () => {
    const loader = fakeLoader({
      "2026-11": {
        kind: "found",
        month: { year: 2026, month: 11, fuseau: "GMT", cities: new Map() },
      },
    });
    const { response } = await get("/prayers?lat=33.57&lon=-7.59&date=2026-11-11", deps(loader));
    expect(response.status).toBe(502);
  });
});
