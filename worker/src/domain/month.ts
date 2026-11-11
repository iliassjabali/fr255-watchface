import { err, ok, type Result } from "./result.js";

/** Six "HH:MM" local times: Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha. */
export type DayRow = readonly [string, string, string, string, string, string];

export type MonthFile = {
  readonly year: number;
  readonly month: number;
  readonly fuseau: string;
  /** City id to rows, index = day of month - 1. */
  readonly cities: ReadonlyMap<number, readonly DayRow[]>;
};

const PAYLOAD = /\.push\((\{[\s\S]*\})\);?\s*$/;
const HHMM = /^\d{2}:\d{2}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isDayRow(value: unknown): value is DayRow {
  return (
    Array.isArray(value) &&
    value.length === 6 &&
    value.every((cell) => typeof cell === "string" && HHMM.test(cell))
  );
}

function parseCity(value: unknown): readonly [number, readonly DayRow[]] | undefined {
  if (!isRecord(value)) return undefined;
  const id = value["c"];
  const rows = value["h"];
  if (typeof id !== "number" || !Array.isArray(rows) || !rows.every(isDayRow)) return undefined;
  return [id, rows];
}

function parsePayload(payload: unknown): Result<MonthFile, string> {
  if (!isRecord(payload)) return err("payload is not an object");
  const { annee, mois, fuseau, villes } = payload;
  if (typeof annee !== "number" || typeof mois !== "number" || typeof fuseau !== "string") {
    return err("missing annee, mois or fuseau");
  }
  if (!Array.isArray(villes)) return err("missing villes");
  const cities = new Map<number, readonly DayRow[]>();
  for (const entry of villes) {
    const city = parseCity(entry);
    if (!city) return err("malformed city entry");
    cities.set(city[0], city[1]);
  }
  return ok({ year: annee, month: mois, fuseau, cities });
}

export function parseMonthFile(text: string): Result<MonthFile, string> {
  const match = PAYLOAD.exec(text.trim());
  if (!match?.[1]) return err("not a Habous month file");
  try {
    return parsePayload(JSON.parse(match[1]) as unknown);
  } catch {
    return err("payload is not valid JSON");
  }
}

/** Times of one city for one day of the month (day starts at 1). */
export function selectDay(month: MonthFile, cityId: number, day: number): DayRow | undefined {
  return month.cities.get(cityId)?.[day - 1];
}
