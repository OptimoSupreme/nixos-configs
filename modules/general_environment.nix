#### General Purpose Environment ####

{ pkgs, ... }:

{
  ## Boot splash
  boot = {
    kernelParams = [ "quiet" ];
    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };
  };

  ## Hardware
  hardware = {
    graphics.enable = true;
    bluetooth.enable = true;
    sane.enable = true;
    enableRedistributableFirmware = true;
  };

  ## Desktop Environment Services
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    fwupd.enable = true;
    fprintd.enable = true;
  };

  ## Fingerprint enrolment workaround for https://github.com/NixOS/nixpkgs/issues/561267
  environment.extraInit = ''
    export XDG_DATA_DIRS=$XDG_DATA_DIRS''${XDG_DATA_DIRS:+:}${pkgs.gdm}/share/gsettings-schemas/${pkgs.gdm.name}
  '';

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

  ## Package Additions
  environment.systemPackages = with pkgs; [
    kdePackages.breeze
    git
    unzip
    ptyxis
    onlyoffice-desktopeditors
    sticky-notes
    resources
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.dash-to-panel
    gnome50Extensions."impatience@gfxmonk.net"  # gnomeExtensions.impatience is a stale git build (GNOME 45-49); swap back once nixpkgs bumps it
    gnomeExtensions.pip-on-top
  ];

  ## Flatpak with Flathub
  services.flatpak.enable = true;
  environment.etc."flatpak/remotes.d/flathub.flatpakrepo".source = ../assets/flathub.flatpakrepo;

  ## dconf
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      { keyfiles = [ ../assets/dconf/general_environment ]; }
    ];
    profiles.gdm.databases = [
      { keyfiles = [ ../assets/dconf/gdm ]; }
    ];
  };
}
