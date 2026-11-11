import { readFileSync } from "node:fs";
import { join } from "node:path";

export function fixture(name: string): string {
  return readFileSync(join(import.meta.dirname, "fixtures", name), "utf8");
}
