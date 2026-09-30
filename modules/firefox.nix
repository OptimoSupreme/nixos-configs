#### Firefox Configuration ####

{ ... }:

{
  programs.firefox = {
    enable = true;

    policies = {
      NoDefaultBookmarks = true;
      DisableFirefoxStudies = true;
      DisableRemoteImprovements = true;

      # Locked (not just defaulted in mozilla.cfg) because Mozilla's Nimbus
      # experiment system writes user-branch values that override defaultPref.
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        Locked = true;
      };

      # AI features default to blocked but stay user-changeable in Settings
      # (Locked = false only sets default prefs). Default covers every feature,
      # including ones Mozilla adds later, and flips each feature's own enable
      # pref (browser.ml.chat.enabled, browser.ml.linkPreview.enabled, ...).
      AIControls = {
        Default = { Value = "blocked"; Locked = false; };
      };

      # The new sidebar (sidebar.revamp, default since Firefox 157) is left on:
      # the pref is going away at the end of 2027. mozilla.cfg keeps its
      # toolbar button from being added (open panels with Ctrl+B / Ctrl+H or
      # View > Sidebar).
      # Vertical tabs stay locked off so Nimbus rollouts can't switch them on.
      Preferences = {
        "sidebar.verticalTabs" = { Value = false; Status = "locked"; };
        "signon.firefoxRelay.feature" = { Value = "disabled"; Status = "locked"; };
      };

      # Extensions
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "sponsorBlocker@ajay.app" = {
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
        };
      };

      # Search Engines
      SearchEngines = {
        Default = "Google";
        Remove = [
          "Bing"
          "DuckDuckGo"
          "eBay"
          "Wikipedia (en)"
          "Perplexity"
          "Perplexity AI"
          "Ask Perplexity"
        ];
      };
    };

    autoConfig = builtins.readFile ../assets/firefox/mozilla.cfg;
  };
}
