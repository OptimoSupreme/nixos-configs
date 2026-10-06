#### Firefox Configuration ####

{ ... }:

{
  programs.firefox = {
    enable = true;

    policies = {
      NoDefaultBookmarks = true;
      DisableFirefoxStudies = true;
      DisableRemoteImprovements = true;

      ## Suggestions (locked: Nimbus experiments write user-branch prefs that beat mozilla.cfg)
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        Locked = true;
      };

      ## AI features off by default, still user-changeable
      AIControls = {
        Default = {
          Value = "blocked";
          Locked = false;
        };
      };

      ## Locked Preferences
      Preferences = {
        "sidebar.verticalTabs" = {
          Value = false;
          Status = "locked";
        };
        "signon.firefoxRelay.feature" = {
          Value = "disabled";
          Status = "locked";
        };
      };

      ## Extensions
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

      ## Search Engines
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

    ## Default Preferences
    autoConfig = builtins.readFile ../assets/firefox/mozilla.cfg;
  };
}
