import { describe, expect, it } from "vitest";
import { createCloudflareRateLimiter } from "../src/adapters/cloudflare-rate-limiter.js";

describe("createCloudflareRateLimiter", () => {
  it("passes the key to the binding and returns its verdict", async () => {
    const keys: string[] = [];
    const binding = {
      limit: async ({ key }: { key: string }) => {
        keys.push(key);
        return { success: key !== "blocked" };
      },
    };
    const limiter = createCloudflareRateLimiter(binding);
    expect(await limiter.allow("1.2.3.4")).toBe(true);
    expect(await limiter.allow("blocked")).toBe(false);
    expect(keys).toEqual(["1.2.3.4", "blocked"]);
  });

  it("allows every request when the binding is missing", async () => {
    expect(await createCloudflareRateLimiter(undefined).allow("1.2.3.4")).toBe(true);
  });

  it("allows the request when the binding throws", async () => {
    const binding = {
      limit: async (): Promise<{ success: boolean }> => {
        throw new Error("binding down");
      },
    };
    expect(await createCloudflareRateLimiter(binding).allow("1.2.3.4")).toBe(true);
  });
});
