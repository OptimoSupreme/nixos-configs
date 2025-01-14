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

  # enable pipewire with alsa aupport
  hardware.alsa.enable = true;

  # enable avahi
  services.avahi.enable = true;

  # setup resmaple for garbage  usb DAC compatibility :)
  environment.etc."asound.conf".text = ''
    # Resample for the outdoor speaker USB DAC
    pcm.usb_dac1 {
        type hw
        card 1
        device 0
    }

    pcm.resampled_dac1 {
        type plug
        slave {
            pcm "usb_dac1"
            rate 48000
        }
    }

    # Resample for the dining room USB DAC
    pcm.usb_dac2 {
        type hw
        card 2
        device 0
    }

    pcm.resampled_dac2 {
        type plug
        slave {
            pcm "usb_dac2"
            rate 48000
        }
    }
  '';

  # systemd units
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
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/outdoor_speakers.conf";
      };
    };
    dining-room = {
      description = "Dining room shairport-sync instance";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "shairport";
        Group = "shairport";
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/dining_room.conf";
      };
    };
  };


  services.dbus.policies = [
    {
      name = "shairport-sync";
      policy = ''
        <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
        "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
        <busconfig>
          <policy user="shairport">
            <allow own="org.gnome.ShairportSync.*"/>
            <allow own="org.mpris.MediaPlayer2.ShairportSync.*"/>
            <allow send_destination="org.gnome.ShairportSync.*"/>
            <allow send_destination="org.mpris.MediaPlayer2.ShairportSync.*"/>
          </policy>
        </busconfig>
      '';
    }
  ];
}