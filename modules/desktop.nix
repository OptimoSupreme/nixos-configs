#### Shared GNOME Desktop ####

{
  inputs,
  lib,
  pkgs,
  ...
}:

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

  ## Fonts
  fonts = {
    packages = with pkgs; [
      ubuntu-sans
      nerd-fonts.ubuntu-sans
      noto-fonts
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Ubuntu Sans" ];
      monospace = [ "UbuntuSansMono Nerd Font Mono" ];
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
