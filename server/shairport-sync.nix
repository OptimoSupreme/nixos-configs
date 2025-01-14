{ config, pkgs, ... }:

{
  # Open firewall ports
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

  # Packages
  environment.systemPackages = with pkgs; [
    alsa-utils
    shairport-sync-airplay2
  ];

  # Enable PipeWire with ALSA support
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };

  # Setup resample for USB DAC compatibility
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

  # Systemd units for Shairport Sync instances
  systemd.services = {
    outdoor-speakers = {
      description = "Outdoor speakers Shairport Sync instance";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.gnome.ShairportSync.OutdoorSpeakers";
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -a 'Outdoor Speakers' -o alsa -- -d resampled_dac1";
      };
    };
    dining-room = {
      description = "Dining room Shairport Sync instance";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.gnome.ShairportSync.DiningRoom";
        ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -a 'Dining Room' -o alsa -- -d resampled_dac2";
      };
    };
  };
}