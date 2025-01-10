{ config, pkgs, ... }:

{
  services = {
    audiobookshelf = {
      enable = true;
      openFirewall = true;
      port = 8000;
      host = "10.0.0.45";
    };
  };
}