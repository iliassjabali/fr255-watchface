import type { MonthFile } from "./month.js";

export type MonthLoad =
  | { readonly kind: "found"; readonly month: MonthFile }
  | { readonly kind: "missing" }
  | { readonly kind: "failed" };

/** Driven port: loads the Habous file of one Gregorian month (month starts at 1). */
export type MonthLoader = (year: number, month: number) => Promise<MonthLoad>;

/** Driven port: decides whether a client may make one more request now. */
export type RateLimiter = {
  readonly allow: (key: string) => Promise<boolean>;
};
