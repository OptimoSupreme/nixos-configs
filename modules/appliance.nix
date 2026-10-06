#### Headless Appliance ####

{ lib, ... }:

{
  ## Hardware
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  ## Boot
  boot.loader.timeout = lib.mkDefault 0;
  boot.kernelParams = [ "quiet" ];

  ## Audio
  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  ## SSH
  services.openssh = {
    enable = lib.mkDefault true;
    settings.PermitRootLogin = lib.mkDefault "no";
  };
}
