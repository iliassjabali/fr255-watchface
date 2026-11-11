const MINUTES_PER_DAY = 1440;
const HHMM = /^(\d{2}):(\d{2})$/;
const FUSEAU = /^GMT(?:([+-])(\d{1,2}))?$/;

/** Offset in minutes east of UTC for "GMT", "GMT+1", "GMT-1". */
function offsetMinutes(fuseau: string): number | undefined {
  const match = FUSEAU.exec(fuseau);
  if (!match) return undefined;
  const [, sign, hours] = match;
  if (sign === undefined || hours === undefined) return 0;
  const offset = Number(hours) * 60;
  return sign === "-" ? -offset : offset;
}

/** Converts a local "HH:MM" time to minutes after midnight UTC (wrapped into one day). */
export function toUtcMinutes(hhmm: string, fuseau: string): number | undefined {
  const time = HHMM.exec(hhmm);
  const offset = offsetMinutes(fuseau);
  if (!time || offset === undefined) return undefined;
  const hours = Number(time[1]);
  const minutes = Number(time[2]);
  if (hours > 23 || minutes > 59) return undefined;
  const utc = hours * 60 + minutes - offset;
  return ((utc % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
}
