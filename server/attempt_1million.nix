{ config, pkgs, lib, ... }:

{
  # user and group
  users = {
    users.shairport = {
      description    = "Shairport user";
      isSystemUser   = true;
      createHome     = true;
      home           = "/var/lib/shairport-sync";
      group          = "shairport";
      extraGroups    = [ "audio" ]
        ++ lib.optional (config.hardware.pulseaudio.enable 
                         || config.services.pipewire.pulse.enable)
                        "pulse";
    };
    groups.shairport = {};
  };

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

  # enable pulseaudio
  services.pipewire.enable = false;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;
  hardware.pulseaudio.systemWide = true;
  
  # enable Avahi
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.userServices = true;
  };

  # systemd services
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
      after       = [ "network.target" "avahi-daemon.service" ];
      serviceConfig = {
        User             = "shairport";
        Group            = "shairport";
        # ExecStart = "${pkgs.shairport-sync-airplay2}/bin/shairport-sync -c /srv/shairport-sync/outdoor_speakers.conf";
        ExecStart        = ''
          ${pkgs.shairport-sync-airplay2}/bin/shairport-sync \
            -v \
            -o pa -- -d "alsa_output.usb-Generic_USB_Audio_20210726905926-00.analog-stereo"
        '';
        Restart          = "on-failure";
        RuntimeDirectory = "shairport-sync";
      };
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
}