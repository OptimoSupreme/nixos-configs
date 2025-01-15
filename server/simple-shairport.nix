{ config, pkgs, ... }:

{
  # enable pulseaudio
  services.pipewire.enable = false;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;
  hardware.pulseaudio.systemWide = true;

  nixpkgs.config.pulseaudio = true;
  
  # enable shairport-sync module
  services.shairport-sync.enable = true;
  services.shairport-sync.openFirewall = true;
}