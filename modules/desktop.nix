#### Shared GNOME Desktop ####

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
in
{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  ## Hardware
  hardware = {
    graphics.enable = true;
    bluetooth = {
      enable = true;
      settings.General.Experimental = true; # device battery levels
    };
    sane = {
      enable = true;
      extraBackends = [ pkgs.sane-airscan ];
    };
    enableRedistributableFirmware = true;
  };

  ## Boot Splash
  boot = {
    tmp.cleanOnBoot = true;
    consoleLogLevel = lib.mkDefault 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];
    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };
  };

  ## Desktop Services
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    printing.enable = true;
    ipp-usb.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    resolved.enable = true;
    fwupd.enable = true;
    fprintd.enable = true;
  };

  ## Disk Health (SMART warnings as desktop notifications)
  services.smartd = {
    enable = true;
    notifications.wall.enable = false;
    notifications.x11.enable = false;
    defaults.autodetected = "-a -m <nomailer> -M exec ${lib.getExe smartdNotify}";
  };

  ## Captive Portal Detection
  networking.networkmanager.settings.connectivity = {
    uri = "http://nmcheck.gnome.org/check_network_status.txt";
    interval = 300;
  };

  ## Time Zone (set by GNOME from location)
  time.timeZone = lib.mkDefault null;
  programs.dconf.profiles.user.databases = [
    { settings."org/gnome/desktop/datetime".automatic-timezone = true; }
  ];

  ## Out of Memory Killer
  systemd.oomd = {
    enableRootSlice = true;
    enableUserSlices = true;
  };

  ## Faster Shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = "45s";
  systemd.user.extraConfig = "DefaultTimeoutStopSec=45s";

  ## Wayland for Electron and Chromium apps
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  ## Fingerprint enrolment workaround for https://github.com/NixOS/nixpkgs/issues/561267
  environment.extraInit = ''
    export XDG_DATA_DIRS=$XDG_DATA_DIRS''${XDG_DATA_DIRS:+:}${pkgs.gdm}/share/gsettings-schemas/${pkgs.gdm.name}
  '';

  ## SSH installed, started manually
  services.openssh.enable = true;
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
  documentation.nixos.enable = false;

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
      subpixel.rgba = "rgb"; # matches font-antialiasing='rgba' in dconf for non-GTK apps
    };
  };

  ## Packages
  environment.systemPackages = with pkgs; [
    kdePackages.breeze
    git
    microfetch
    unzip
    ptyxis
    onlyoffice-desktopeditors
    sticky-notes
    resources
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.dash-to-panel
    gnome50Extensions."impatience@gfxmonk.net" # gnomeExtensions.impatience is stuck on GNOME 45-49
    gnomeExtensions.pip-on-top
  ];

  ## Flatpak with Flathub
  services.flatpak.enable = true;
  environment.etc."flatpak/remotes.d/flathub.flatpakrepo".source = ../assets/flathub.flatpakrepo;

  ## Command Not Found hint and `,` runner
  programs.nix-index-database.comma.enable = true;

  ## Microfetch on login
  programs.bash.interactiveShellInit = ''
    command -v microfetch >/dev/null && microfetch
  '';

  ## dconf
  programs.dconf = {
    enable = true;
    profiles.gdm.databases = [
      { keyfiles = [ ../assets/dconf/gdm ]; }
    ];
  };
}
