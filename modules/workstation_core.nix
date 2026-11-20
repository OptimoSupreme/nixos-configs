#### Shared Workstation Configuration ####

{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  smartdNotify = pkgs.writeShellApplication {
    name = "smartd-notify";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
      systemd
      util-linux
    ];
    text = ''
      loginctl list-users --no-legend | awk '{ print $2 }' | while read -r user; do
        bus="/run/user/$(id -u "$user")/bus"
        [ -S "$bus" ] || continue
        runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
          notify-send --urgency=critical --app-name=smartd --icon=drive-harddisk \
          "Disk problem: $SMARTD_DEVICESTRING" "$SMARTD_MESSAGE"
      done
    '';
  };
  # blurMyShell is a workaround: drop it and assets/blur-my-shell-metadata.json once nixpkgs ships 76+
  blurMyShell = pkgs.gnomeExtensions.blur-my-shell.overrideAttrs {
    version = "78"; # 73+ keep windows opaque in the overview, 76+ fix GPU memory leaks
    src = pkgs.fetchzip {
      url = "https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v78.shell-extension.zip";
      hash = "sha256-HlaJCzOdjs7L/36tr54SEvulyqynNm0teatftZlpM+8=";
      stripRoot = false;
      postFetch = "cp ${../assets/blur-my-shell-metadata.json} $out/metadata.json"; # EGO rewrites it in place
    };
  };
  # screencastExtraFeature from unstable: stable's 7 shells out to gst-inspect-1.0, which is not on PATH
  screencastExtraFeature =
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.gnomeExtensions.screencast-extra-feature;
in
{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  ## Hardware
  hardware = {
    sane = {
      enable = lib.mkDefault true;
      extraBackends = [ pkgs.sane-airscan ];
    };
    enableRedistributableFirmware = lib.mkDefault true;
  };

  ## Boot Splash
  boot = {
    tmp.cleanOnBoot = lib.mkDefault true;
    consoleLogLevel = lib.mkDefault 3;
    initrd.verbose = lib.mkDefault false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];
    plymouth = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "nixos-bgrt";
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };
  };

  ## zramSwap
  zramSwap = {
    enable = lib.mkDefault true;
    memoryMax = lib.mkDefault (8 * 1024 * 1024 * 1024);
    priority = lib.mkDefault 1;
  };

  ## Desktop Services
  services = {
    displayManager.gdm.enable = lib.mkDefault true;
    desktopManager.gnome.enable = lib.mkDefault true;
    pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };
    printing.enable = lib.mkDefault true;
    ipp-usb.enable = lib.mkDefault true;
    avahi.nssmdns4 = lib.mkDefault true;
    resolved.enable = lib.mkDefault true;
    fwupd.enable = lib.mkDefault true;
    fprintd.enable = lib.mkDefault true;
  };

  ## Disk Health (SMART warnings as desktop notifications)
  services.smartd = {
    enable = lib.mkDefault true;
    notifications.wall.enable = lib.mkDefault false;
    notifications.x11.enable = lib.mkDefault false; # the installer ISO has X enabled
    defaults.autodetected = lib.mkDefault "-a -m <nomailer> -M exec ${lib.getExe smartdNotify}";
  };

  ## Captive Portal Detection
  networking.networkmanager.settings.connectivity = {
    uri = lib.mkDefault "http://nmcheck.gnome.org/check_network_status.txt";
    interval = lib.mkDefault 300;
  };

  ## Desktop Defaults
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/datetime".automatic-timezone = true;
        "org/gnome/shell".always-show-log-out = true; # hidden by default on single-user machines
        "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/resources/"
        ];
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/resources" = {
          name = "Resources";
          command = "resources";
          binding = "<Control><Shift>Escape";
        };
      };
    }
  ];

  ## Out of Memory Killer
  systemd.oomd = {
    enableRootSlice = lib.mkDefault true;
    enableUserSlices = lib.mkDefault true;
  };

  ## Faster Shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = lib.mkDefault "45s";
  systemd.user.extraConfig = "DefaultTimeoutStopSec=45s";

  ## Wayland for Electron and Chromium apps
  environment.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";

  ## SSH installed, started manually
  services.openssh.enable = lib.mkDefault true;
  systemd.services.sshd.wantedBy = lib.mkForce [ ];

  ## Package Removals
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-music
    gnome-maps
    gnome-weather
    gnome-contacts
    gnome-clocks
    gnome-characters
    gnome-font-viewer
    gnome-logs
    gnome-system-monitor
    gnome-connections
    gnome-console
    epiphany
    yelp
    snapshot
    seahorse
  ];
  # Hide CUPS web UI icon
  environment.extraSetup = "rm -f $out/share/applications/cups.desktop";
  documentation.nixos.enable = lib.mkDefault false;

  ## Fonts
  fonts = {
    packages = with pkgs; [
      ubuntu-sans
      nerd-fonts.ubuntu-sans
      noto-fonts
    ];
    fontconfig = {
      defaultFonts = {
        sansSerif = [ "Ubuntu Sans" ];
        serif = [ "Noto Serif" ];
        monospace = [ "UbuntuSansMono Nerd Font Mono" ];
      };
      subpixel.rgba = lib.mkDefault "rgb"; # matches font-antialiasing='rgba' in dconf for non-GTK apps
    };
  };

  ## Packages
  environment.systemPackages = with pkgs; [
    kdePackages.breeze
    microfetch
    unzip
    ptyxis
    onlyoffice-desktopeditors
    sticky-notes
    resources
    gnomeExtensions.appindicator
    blurMyShell
    gnomeExtensions.caffeine
    gnomeExtensions.dash-to-panel
    gnome50Extensions."impatience@gfxmonk.net" # gnomeExtensions.impatience is stuck on GNOME 45-49
    gnomeExtensions.pip-on-top
    screencastExtraFeature # desktop and mic audio in the built-in screen recorder
  ];

  ## Flatpak with Flathub
  services.flatpak.enable = lib.mkDefault true;
  environment.etc."flatpak/remotes.d/flathub.flatpakrepo".source = ../assets/flathub.flatpakrepo;

  ## Shell Config
  programs = {
    bash = {
      promptInit = lib.mkDefault ''
        if [ "$TERM" != "dumb" ]; then
          PS1='\n\[\e]0;\u@\h\a\]''${SSH_TTY:+\[\e[33m\]\u\[\e[31m\]@\[\e[32m\]\h\[\e[0m\] }\[\e[33m\]\w\[\e[0m\] \[\e[$(($? ? 31 : 32))m\]\$\[\e[0m\] '
        fi
      '';
      interactiveShellInit = ''
        shopt -s histappend
        HISTSIZE=1000
        HISTFILESIZE=1000
        HISTCONTROL=ignoreboth
        PROMPT_COMMAND="history -a''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
        bind 'set colored-stats on'
        command -v microfetch >/dev/null && microfetch
      '';
    };
    fzf.keybindings = lib.mkDefault true; # Ctrl+R history search
    nix-index-database.comma.enable = lib.mkDefault true; # Command Not Found hint and `,` runner
  };

  ## dconf
  programs.dconf.profiles.gdm.databases = [
    { keyfiles = [ ../assets/dconf/gdm ]; }
  ];
}
