#### Personal Environment ####

{ lib, pkgs, ... }:

let
  user = "justin";
in
{
  imports = [ ./desktop.nix ];

  ## Networking
  networking.firewall.allowedTCPPorts = [ 53317 ]; # LocalSend
  networking.firewall.allowedUDPPorts = [ 53317 ];

  ## Passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  ## Containers and VMs
  virtualisation.podman.enable = lib.mkDefault true;
  virtualisation.libvirtd.enable = lib.mkDefault true;
  programs.virt-manager.enable = lib.mkDefault true;
  users.groups.libvirtd.members = [ user ];

  ## Git
  programs.git = {
    enable = lib.mkDefault true;
    config = {
      user.name = lib.mkDefault "Justin Ward";
      user.email = lib.mkDefault "jward92@gmail.com";
      fetch.prune = lib.mkDefault true;
    };
  };

  ## Shim for non-Nix binaries (some Codium extensions)
  programs.nix-ld.enable = lib.mkDefault true;

  ## Packages
  environment.systemPackages = with pkgs; [
    vscodium
    distrobox
    gh
  ];

  ## Flatpaks
  systemd.services.flatpak-apps =
    let
      flatpaks = [
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
    in
    {
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
  programs.dconf.profiles.user.databases = [
    { keyfiles = [ ../assets/dconf/personal_environment ]; }
  ];
}
