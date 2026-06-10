import { describe, expect, it } from "vitest";
import { makeT, resolveLang } from "../l10n";

describe("l10n", () => {
  it("returns russian for ru/uk/be, english otherwise", () => {
    expect(resolveLang(null, "ru-RU")).toBe("ru");
    expect(resolveLang(null, "uk-UA")).toBe("ru");
    expect(resolveLang(null, "be-BY")).toBe("ru");
    expect(resolveLang(null, "en-US")).toBe("en");
    expect(resolveLang("en", "ru-RU")).toBe("en"); // explicit setting wins
  });

  it("translates known keys and falls back to key", () => {
    const t = makeT("ru");
    expect(t("tab.dashboard")).toBe("Дашборд");
    expect(makeT("en")("tab.dashboard")).toBe("Dashboard");
    expect(t("nope.missing" as never)).toBe("nope.missing");
  });
});
