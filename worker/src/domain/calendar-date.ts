export type CalendarDate = {
  readonly year: number;
  readonly month: number;
  readonly day: number;
};

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

export function parseIsoDate(text: string): CalendarDate | undefined {
  const match = ISO_DATE.exec(text);
  if (!match) return undefined;
  const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const check = new Date(Date.UTC(year, month - 1, day));
  const valid =
    check.getUTCFullYear() === year && check.getUTCMonth() === month - 1 && check.getUTCDate() === day;
  return valid ? { year, month, day } : undefined;
}

export function formatIsoDate({ year, month, day }: CalendarDate): string {
  const pad = (value: number, width: number): string => String(value).padStart(width, "0");
  return `${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}`;
}

export function nextDay({ year, month, day }: CalendarDate): CalendarDate {
  const next = new Date(Date.UTC(year, month - 1, day + 1));
  return { year: next.getUTCFullYear(), month: next.getUTCMonth() + 1, day: next.getUTCDate() };
}

export function utcDateOf(instant: Date): CalendarDate {
  return {
    year: instant.getUTCFullYear(),
    month: instant.getUTCMonth() + 1,
    day: instant.getUTCDate(),
  };
}
