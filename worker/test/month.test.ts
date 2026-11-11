import { describe, expect, it } from "vitest";
import { parseMonthFile, selectDay } from "../src/domain/month.js";
import { toUtcMinutes } from "../src/domain/time.js";
import { fixture } from "./helpers.js";

function parsedNovember() {
  const result = parseMonthFile(fixture("horaires-2026-11.js"));
  if (!result.ok) throw new Error(`fixture should parse: ${result.error}`);
  return result.value;
}

describe("parseMonthFile", () => {
  it("parses the November 2026 fixture", () => {
    const month = parsedNovember();
    expect(month.year).toBe(2026);
    expect(month.month).toBe(11);
    expect(month.fuseau).toBe("GMT");
    expect(month.cities.size).toBe(190);
  });

  it("rejects text that is not a Habous month file", () => {
    expect(parseMonthFile("<html>404</html>").ok).toBe(false);
    expect(parseMonthFile("").ok).toBe(false);
  });

  it("rejects a payload with malformed rows", () => {
    const bad =
      '(window.HORAIRES_MOIS=window.HORAIRES_MOIS||[]).push({"annee":2026,"mois":11,"fuseau":"GMT","villes":[{"c":1,"h":[["5:1"]]}]});';
    expect(parseMonthFile(bad).ok).toBe(false);
  });
});

describe("selectDay", () => {
  it("returns the six times of Casablanca on 2026-11-11", () => {
    expect(selectDay(parsedNovember(), 58, 11)).toEqual([
      "05:28", "06:55", "12:20", "15:10", "17:35", "18:51",
    ]);
  });

  it("returns undefined for an unknown city", () => {
    expect(selectDay(parsedNovember(), 9999, 11)).toBeUndefined();
  });

  it("returns undefined for a day outside the month", () => {
    expect(selectDay(parsedNovember(), 58, 31)).toBeUndefined();
    expect(selectDay(parsedNovember(), 58, 0)).toBeUndefined();
  });
});

describe("toUtcMinutes", () => {
  it("keeps GMT times as they are", () => {
    expect(toUtcMinutes("05:28", "GMT")).toBe(328);
  });

  it("subtracts a positive offset", () => {
    expect(toUtcMinutes("05:28", "GMT+1")).toBe(268);
  });

  it("adds back a negative offset", () => {
    expect(toUtcMinutes("05:28", "GMT-1")).toBe(388);
  });

  it("wraps around midnight", () => {
    expect(toUtcMinutes("00:30", "GMT+1")).toBe(1410);
    expect(toUtcMinutes("23:30", "GMT-1")).toBe(30);
  });

  it("returns undefined for an unknown time zone or a bad time", () => {
    expect(toUtcMinutes("05:28", "Europe/Paris")).toBeUndefined();
    expect(toUtcMinutes("05:28", "")).toBeUndefined();
    expect(toUtcMinutes("25:00", "GMT")).toBeUndefined();
    expect(toUtcMinutes("nope", "GMT")).toBeUndefined();
  });
});
