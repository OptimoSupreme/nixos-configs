{ config, pkgs, ... }:

{
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
      shairport-sync-airplay2
    ];
  };

  # enable pipewire with alsa aupport
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };

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
    outdoor-speakers = {
      description = "Outdoor speakers shairport-sync instance";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/outdoor_speakers.conf";
      };
    };
    dining-room = {
      description = "Dining room shairport-sync instance";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/dining_room.conf";
      };
    };
  };
}