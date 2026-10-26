#### Home Patch ####

{ lib, ... }:

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
  ## Networking
  networking.firewall.allowedTCPPorts = [ 53317 ]; # LocalSend
  networking.firewall.allowedUDPPorts = [ 53317 ];
  networking.hosts."10.0.1.2" = [ "morgoth" ];

  ## Flatpaks
  systemd.services.flatpak-apps.script = ''
    flatpak install --system --noninteractive --assumeyes flathub ${lib.escapeShellArgs flatpaks}
  '';
}
