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

  # networking
  networking = {
    firewall.interfaces.enp2s0.allowedTCPPorts = [ 8080 ];
    firewall.interfaces.enp2s0.allowedUDPPorts = [ 51820 ];
    extraRoutingTables = {
      qbittorrent = 200;
    };
    interfaces.qbittorrent0 = {
      ipv4.addresses = [ { address = "10.0.50.1"; prefixLength = 24; } ];
    };
    routes = [
      { table = "qbittorrent"; destination = "0.0.0.0/0"; interface = "mullvad0"; }
    ];
    wireguard.interfaces = {
      mullvad0 = {
        ips = [ "10.74.173.88/32" "fc00:bbbb:bbbb:bb01::b:ad57/128" ];
        listenPort = 51820;
        privateKeyFile = "/srv/secrets/wireguard-keys/mullvad_private";
        peers = [
          {
            publicKey = "CsysTnZ0HvyYRjsKMPx60JIgy777JhD0h9WpbHbV83o=";
            endpoint = "43.225.189.131:51820";
            allowedIPs = [ "10.0.50.1/32" ];
            persistentKeepalive = 25;
          }
        ];
      };
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
      Environment = [
        "HOME=/srv/media/qbittorrent"
        "QBT_WEBUI_ADDRESS=10.0.0.45"
        "QBT_CONNECTION_INTERFACE=qbittorrent0"
      ];
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
    # audiobookshelf = {
    #   enable = true;
    #   user = "media";
    #   group = "media";
    #   openFirewall = true;
    #   port = 8000;
    #   host = "10.0.0.45";
    # };
    jellyfin = {
      enable = true;
      user = "media";
      group = "media";
      openFirewall = true;
    };
  };
}