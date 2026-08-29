const assert = require("node:assert/strict");
const fs = require("node:fs");
const test = require("node:test");
const vm = require("node:vm");

function loadBridge(hostname = "localhost") {
  const source = fs.readFileSync("web/rewarded_ads.js", "utf8");
  let loader;
  const window = {
    location: { hostname },
    setTimeout,
    clearTimeout,
    console,
  };
  const document = {
    createElement() {
      loader = {
        dataset: {},
        addEventListener(name, callback) {
          this[name] = callback;
        },
      };
      return loader;
    },
    head: { appendChild() {} },
  };
  vm.runInNewContext(source, { window, document, console, Set, Promise });
  return { window, loader };
}

function currentPlacement(window) {
  return window.adsbygoogle.at(-1);
}

test("localhost uses official Ad Placement API test mode", () => {
  const { window, loader } = loadBridge();
  assert.equal(window.hitasuraRewardedAds.usesTestAds(), true);
  assert.equal(loader.dataset.adbreakTest, "on");
});

test("production host does not enable test ads", () => {
  const { window, loader } = loadBridge("hitasura.yorimichi-works.jp");
  assert.equal(window.hitasuraRewardedAds.usesTestAds(), false);
  assert.equal(loader.dataset.adbreakTest, undefined);
});

test("completed view grants exactly one reward", async () => {
  const { window } = loadBridge();
  const result = window.hitasuraRewardedAds.show("restore_search_energy");
  const placement = currentPlacement(window);
  let shown = 0;
  placement.beforeReward(() => shown++);
  placement.adViewed();
  placement.adBreakDone({ breakStatus: "viewed" });
  assert.equal(await result, "rewarded");
  assert.equal(shown, 1);
});

test("dismissal and no-fill never grant a reward", async () => {
  const { window } = loadBridge();
  const dismissed = window.hitasuraRewardedAds.show("unlock_ad_001");
  currentPlacement(window).adDismissed();
  assert.equal(await dismissed, "notRewarded");

  const noFill = window.hitasuraRewardedAds.show("unlock_ad_002");
  currentPlacement(window).adBreakDone({ breakStatus: "noAdPreloaded" });
  assert.equal(await noFill, "unavailable");
});

test("adBreakDone cannot grant a reward without adViewed", async () => {
  const { window } = loadBridge("hitasura.yorimichi-works.jp");
  const result = window.hitasuraRewardedAds.show("restore_search_energy");
  const placement = currentPlacement(window);
  placement.beforeReward(() => {});
  placement.adBreakDone({ breakStatus: "viewed" });

  assert.equal(await result, "unavailable");
});

test("a concurrent request is rejected", async () => {
  const { window } = loadBridge();
  const first = window.hitasuraRewardedAds.show("first");
  assert.equal(
    await window.hitasuraRewardedAds.show("second"),
    "loadFailed",
  );
  currentPlacement(window).adDismissed();
  assert.equal(await first, "notRewarded");
});
