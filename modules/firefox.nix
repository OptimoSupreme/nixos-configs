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

      # Same Nimbus problem: rollouts flip sidebar.revamp to user-branch true
      # seconds after startup, which injects the sidebar-button widget into
      # nav-bar regardless of browser.uiCustomization.state.
      Preferences = {
        "sidebar.revamp" = { Value = false; Status = "locked"; };
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
          "Amazon.com"
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
