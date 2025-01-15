{ config, pkgs, ... }:

{
  # packages
  environment = {
    systemPackages = with pkgs; [
      nqptp
      shairport-sync-airplay2
    ];
  };

  # enable pulseaudio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true; # if not already enabled
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  systemd.services = {
    nqptp = {
      description = "Network Precision Time Protocol for Shairport Sync";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nqptp}/bin/nqptp";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
  
  services.shairport-sync = {
    enable = true;
    openFirewall = true;
    package = pkgs.shairport-sync-airplay2;
    arguments = "-v -o pa";
  };
}