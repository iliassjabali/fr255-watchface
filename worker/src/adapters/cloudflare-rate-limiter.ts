import type { RateLimiter } from "../domain/ports.js";

/** The part of the Workers Rate Limiting binding that this adapter uses. */
export type RateLimitBinding = {
  readonly limit: (options: { key: string }) => Promise<{ success: boolean }>;
};

/**
 * Wraps the Cloudflare binding. Without a binding (local run, tests) or when the binding
 * fails, the request is allowed: the limit is off, and the Worker does not crash.
 */
export function createCloudflareRateLimiter(binding: RateLimitBinding | undefined): RateLimiter {
  return {
    allow: async (key) => {
      if (!binding) return true;
      try {
        return (await binding.limit({ key })).success;
      } catch {
        return true;
      }
    },
  };
}
