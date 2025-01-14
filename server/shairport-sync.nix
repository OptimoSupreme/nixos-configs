{ config, pkgs, ... }:

{
  # packages
  environment = {
    systemPackages = with pkgs; [
      alsa-utils
    ];
  };

  # # enable pipewire with alsa aupport
  # hardware.alsa.enable = true;

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

  # module
  services.shairport-sync = {
    enable = true;
    package = shairport-sync-airplay2;
    openFirewall = true;
    arguments = "-a 'Dining Room' -o alsa -- -d resampled_dac2";
  }
}