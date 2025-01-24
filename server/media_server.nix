{ config, pkgs, ... }:

{
  # users and groups
  users.groups.media = {};
  users.users.media = {
    isSystemUser = true;
    group = "media";
    shell = pkgs.bash;
    home = "/srv/media/qbittorrent";
  };

  # directory creation
  systemd.tmpfiles.rules = [
    "d /srv/media 0770 media media - -"
    "d /srv/media/audiobooks 0770 media media - -"
    "d /srv/media/ebooks 0770 media media - -"
    "d /srv/media/downloads 0770 media media - -"
    "d /srv/media/incomplete 0770 media media - -"
    "d /srv/media/movies 0770 media media - -"
    "d /srv/media/music 0770 media media - -"
    "d /srv/media/torrents 0770 media media - -"
    "d /srv/media/tv 0770 media media - -"
    "d /srv/media/qbittorrent 0770 media media - -"
  ];

  # vpn interface
  networking.wireguard.interfaces = {
    "wg1" = {
      ips = [ "10.73.114.193/32" "fc00:bbbb:bbbb:bb01::a:72c0/128" ];
      privateKey = "2CkEIKgMkA+rISZMcrAzJatz8GkIfqz/YzoMlbAj61Y=";
      peers = [
        {
          publicKey = "LLkA2XSBvfUeXgLdMKP+OTQeKhtGB03kKskJEwlzAE8=";
          endpoint = "43.225.189.162:51820";
          allowedIPs = [];
        }
      ];
    };
  };  
  
  # applications
  environment.systemPackages = with pkgs; [ qbittorrent-nox jellyfin jellyfin-ffmpeg jellyfin-web ];
  nixpkgs.config.permittedInsecurePackages = [ "dotnet-sdk-6.0.428" "aspnetcore-runtime-6.0.36" ];
  
  systemd.services.qbittorrent = {
    description = "qBittorrent-nox Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
      Restart = "on-failure";
      User = "media";
      Environment = [ "HOME=/srv/media/qbittorrent" ];
      WorkingDirectory = "/srv/media/qbittorrent";
      AmbientCapabilities= "CAP_NET_RAW";
    };
  };
  services = {
    sonarr = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
    radarr = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
    lidarr = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
    readarr = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
    bazarr = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
    prowlarr = {
      enable = true;
      openFirewall = true;
    };
    audiobookshelf = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
      port = 8000;
      host = "10.0.0.45";
    };
    jellyfin = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
  };
}