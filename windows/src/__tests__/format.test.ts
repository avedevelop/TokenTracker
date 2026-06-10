import { describe, expect, it } from "vitest";
import { formatCost, formatTokens, countdown } from "../format";

describe("format", () => {
  it("formats tokens with K/M suffix", () => {
    expect(formatTokens(0)).toBe("0");
    expect(formatTokens(950)).toBe("950");
    expect(formatTokens(127_482)).toBe("127.5K");
    expect(formatTokens(2_400_000)).toBe("2.4M");
  });

  it("formats cost as USD", () => {
    expect(formatCost(0)).toBe("$0.00");
    expect(formatCost(2.345)).toBe("$2.35");
  });

  it("renders countdown to a future reset", () => {
    const in2h15m = new Date(Date.now() + (2 * 60 + 15) * 60_000).toISOString();
    expect(countdown(in2h15m, "en")).toBe("2h 15m");
    expect(countdown(in2h15m, "ru")).toBe("2ч 15м");
    expect(countdown(null, "en")).toBe("—");
    const past = new Date(Date.now() - 60_000).toISOString();
    expect(countdown(past, "en")).toBe("0m");
  });
});
