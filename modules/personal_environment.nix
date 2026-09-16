#### Personal Environment ####

{ lib, pkgs, ... }:

let
  user = "justin";
in

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
    vscodium
    distrobox
    gh
    opensc
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

  ## Install my Flatpaks
  systemd.services.flatpak-apps = let
    flatpaks = [
      "com.slack.Slack"
      "us.zoom.Zoom"
      "com.discordapp.Discord"
      "org.gnome.Fractal"
      "org.jellyfin.JellyfinDesktop"
      "com.spotify.Client"
      "com.valvesoftware.Steam"
      "com.usebottles.bottles"
      "org.localsend.localsend_app"
      "app.drey.Warp"
      "org.freecad.FreeCAD"
      "org.gimp.GIMP"
    ];
  in {
    description = "Install the personal flatpak app set";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig = {
      StartLimitIntervalSec = 3600;
      StartLimitBurst = 120;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
    };
    path = [ pkgs.flatpak ];
    script = ''
      flatpak install --system --noninteractive --assumeyes flathub ${lib.escapeShellArgs flatpaks}
    '';
  };

  ## dconf
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      { keyfiles = [ ../assets/dconf/personal_environment ]; }
    ];
    profiles.gdm.databases = [
      { keyfiles = [ ../assets/dconf/gdm ]; }
    ];
  };

  ## Enable Containers and VM's
  virtualisation.podman.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ user ];

  ## Passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = false;

  ## Disabled SSH Service
  services.openssh.enable = true;
  systemd.services.sshd.wantedBy = lib.mkForce [ ];

  ## Git identity
  programs.git = {
    enable = true;
    config = {
      user.name = "Justin Ward";
      user.email = "jward92@gmail.com";
    };
  };

  ## Enable CAC
  services.pcscd.enable = true;
  environment.etc."opensc.conf".source = ../assets/cac/opensc.conf;
  security.pki.certificateFiles = [ ../assets/cac/DoD_PKI_bundle.pem ];
  programs.firefox.policies.SecurityDevices = {
    OpenSC = "${pkgs.opensc}/lib/opensc-pkcs11.so";
    "p11-kit-trust" = "${pkgs.p11-kit}/lib/pkcs11/p11-kit-trust.so";
  };

  ## LocalSend Ports
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];

  ## Shim for non-Nix binaries (needed for some Codium extensions)
  programs.nix-ld.enable = true;
}
