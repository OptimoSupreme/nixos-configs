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
  security.sudo.wheelNeedsPassword = false;

  ## Containers and VMs
  virtualisation.podman.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ user ];

  ## Git identity
  programs.git = {
    enable = true;
    config = {
      user.name = "Justin Ward";
      user.email = "jward92@gmail.com";
    };
  };

  ## Shim for non-Nix binaries (some Codium extensions)
  programs.nix-ld.enable = true;

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
