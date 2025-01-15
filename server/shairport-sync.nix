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
      extraGroups    = [ "pulse-access" ];
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
  hardware = {
    pulseaudio = {
      enable = true;
      support32Bit = true;
      systemWide = true;
    };
  };
  
  # enable Avahi
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.userServices = true;
    allowInterfaces = [ "enp2s0" ];
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
    dining-room = {
      description = "Dining room speakers shairport-sync instance";
      after       = [ "network.target" "avahi-daemon.service" ];
      serviceConfig = {
        User             = "shairport";
        Group            = "shairport";
        # ExecStart = "${pkgs.shairport-sync-airplay2}/bin/shairport-sync -c /srv/shairport-sync/dining_room.conf";
        ExecStart        = ''
          ${pkgs.shairport-sync-airplay2}/bin/shairport-sync \
            -v \
            -a "Dining Room"
            -p 7000 \
            --airplay_device_id_offset=0 \
            -o pa -- -d "alsa_output.usb-Generic_USB_Audio_20210726905926-00.analog-stereo"
        '';
        Restart          = "on-failure";
        RuntimeDirectory = "shairport-sync";
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
            -a "Outdoor Speakers"
            -p 7001 \
            --airplay_device_id_offset=1 \
            -o pa -- -d "alsa_output.usb-Generic_USB_Audio_20210726905926-00.analog-stereo.2"
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

# run `sudo -u pulse PULSE_RUNTIME_PATH=/run/pulse pactl list sinks short` to display available sinks
# run `sudo -u pulse alsamixer` to adjust volume levels
# run `sudo alsactl store` so save the volume levels persistently