{ config, pkgs, ... }:

{
  # add shairport-sync user
    users.users.shairport = {
      description = "Shairport user";
      isSystemUser = true;
      createHome = true;
      home = "/var/lib/shairport-sync";
      group = "shairport";
      extraGroups = [ "audio" ];
    };
    users.groups.shairport = {};
  
  # open firewall ports
  networking.firewall = {
    interfaces."enp2s0" = {
      allowedTCPPorts = [
        3689
        5353
        5000
      ];
      allowedUDPPorts = [
        5353
      ];
      allowedTCPPortRanges = [
        { from = 7000; to = 7001; }
        { from = 32768; to = 60999; }
      ];
      allowedUDPPortRanges = [
        { from = 319; to = 320; }
        { from = 6000; to = 6009; }
        { from = 32768; to = 60999; }
      ];
    };
  };

  # packages
  environment = {
    systemPackages = with pkgs; [
      alsa-utils
      nqptp
      shairport-sync-airplay2
    ];
  };

  # enable pulseaudio
  services.pipewire.enable = false;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # enable avahi
  # services.avahi.enable = true;

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
    outdoor-speakers = {
      description = "Outdoor speakers shairport-sync instance";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "shairport";
        Group = "shairport";
        # ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/outdoor_speakers.conf";
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -v -o pa";

      };
    };
    # dining-room = {
    #   description = "Dining room shairport-sync instance";
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     User = "shairport";
    #     Group = "shairport";
    #     ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/dining_room.conf";
    #   };
    # };
  };
}