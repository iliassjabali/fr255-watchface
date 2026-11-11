import citiesData from "../data/cities.json";
import { createCloudflareRateLimiter } from "./adapters/cloudflare-rate-limiter.js";
import { createHabousLoader } from "./adapters/habous-loader.js";
import type { City } from "./domain/nearest-city.js";
import { handlePrayers } from "./handler.js";

const cities: readonly City[] = citiesData;

type Env = {
  /** Optional: when absent, the rate limit is off. */
  readonly PRAYERS_RATE_LIMITER?: RateLimit;
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const loadMonth = createHabousLoader({
      cache: caches.default,
      fetcher: (upstream) => fetch(upstream),
    });
    const rateLimiter = createCloudflareRateLimiter(env.PRAYERS_RATE_LIMITER);
    return handlePrayers(request, { cities, loadMonth, rateLimiter, now: () => new Date() });
  },
} satisfies ExportedHandler<Env>;
