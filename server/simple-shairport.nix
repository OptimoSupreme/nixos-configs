{ config, pkgs, ... }:

{
  # enable pipewire with alsa and pulse support
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  
  # enable shairport-sync module
  services.shairport-sync.enable = true;
  services.shairport-sync.openFirewall = true;
}