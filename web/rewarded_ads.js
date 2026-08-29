(function () {
  "use strict";

  const publisherId = "ca-pub-3186852093801241";
  const testHosts = new Set(["localhost", "127.0.0.1", "::1"]);
  const testMode = testHosts.has(window.location.hostname);
  let pending = false;
  let apiFailed = false;

  window.adsbygoogle = window.adsbygoogle || [];
  window.adBreak = window.adConfig = function (config) {
    window.adsbygoogle.push(config);
  };

  const script = document.createElement("script");
  script.async = true;
  script.crossOrigin = "anonymous";
  script.src =
    "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=" +
    publisherId;
  if (testMode) {
    script.dataset.adbreakTest = "on";
  }
  script.addEventListener("error", function () {
    apiFailed = true;
  });
  document.head.appendChild(script);

  window.hitasuraRewardedAds = {
    isSupported: function () {
      return !apiFailed && typeof window.adBreak === "function";
    },

    usesTestAds: function () {
      return testMode;
    },

    show: function (placementName) {
      if (apiFailed || pending || typeof window.adBreak !== "function") {
        return Promise.resolve(pending ? "loadFailed" : "unavailable");
      }
      pending = true;

      return new Promise(function (resolve) {
        let settled = false;
        const timeout = window.setTimeout(function () {
          finish("loadFailed");
        }, 45000);

        function finish(result) {
          if (settled) return;
          settled = true;
          pending = false;
          window.clearTimeout(timeout);
          resolve(result);
        }

        try {
          window.adBreak({
            type: "reward",
            name: String(placementName || "reward"),
            beforeReward: function (showAd) {
              // The Flutter button is the opt-in reward prompt.
              showAd();
            },
            adDismissed: function () {
              finish("notRewarded");
            },
            adViewed: function () {
              finish("rewarded");
            },
            adBreakDone: function (placementInfo) {
              if (settled) return;
              const status = placementInfo && placementInfo.breakStatus;
              if (status === "dismissed") {
                finish("notRewarded");
              } else {
                finish("unavailable");
              }
            },
          });
        } catch (error) {
          console.error("[RewardedAd] Ad Placement API error", error);
          finish("loadFailed");
        }
      });
    },
  };
})();
