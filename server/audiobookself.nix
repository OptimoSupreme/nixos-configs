{ config, pkgs, ... }:

{
  services = {
    audiobookshelf = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
      port = 8000;
      host = "10.0.0.45";
    };
  };
}