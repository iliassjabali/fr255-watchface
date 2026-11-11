import citiesData from "../data/cities.json";
import { createHabousLoader } from "./adapters/habous-loader.js";
import type { City } from "./domain/nearest-city.js";
import { handlePrayers } from "./handler.js";

const cities: readonly City[] = citiesData;

export default {
  async fetch(request: Request): Promise<Response> {
    const loadMonth = createHabousLoader({
      cache: caches.default,
      fetcher: (upstream) => fetch(upstream),
    });
    return handlePrayers(request, { cities, loadMonth, now: () => new Date() });
  },
} satisfies ExportedHandler;
