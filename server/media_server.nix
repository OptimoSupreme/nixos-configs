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
    nat = {
      enable = true;
      internalInterfaces = [ "br0" "enp2s0" ];
      routes = [
        {
          sourceAddress = "0.0.0.0/0";
          sourcePort = 8080;
          destination = "10.233.0.2";
          destinationPort = 8080;
        }
      ];
    };
  };

  # applications
  environment.systemPackages = with pkgs; [ jellyfin jellyfin-ffmpeg jellyfin-web ];
  nixpkgs.config.permittedInsecurePackages = [ "dotnet-sdk-6.0.428" "aspnetcore-runtime-6.0.36" ];
  
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

  # torrent + vpn container
  containers.torbox = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.0.1";
    localAddress = "10.233.0.2";
    config = { config, pkgs, ... }:
    
    {
      # users and groups
      users.groups.media = {};
      users.users.media = {
        isSystemUser = true;
        group = "media";
        shell = pkgs.bash;
        home = "/srv/media/qbittorrent";
      };

      # networking
        networking.defaultGateway = null;
        networking.interfaces.eth0.ipv4.addresses = [{ address = "10.233.0.2"; prefixLength = 24; }];
        networking.firewall.interfaces.mullvad0.allowedUDPPorts = [ 51820 ];
        networking.wireguard.interfaces = {
          mullvad0 = {
            ips = [ "10.64.0.2/32" ]; # example; Mullvad might give you something else
            privateKeyFile = "/etc/wireguard/mullvad-key"; # adjust accordingly
            peers = [
              {
                publicKey = "MULLVAD_PUBLIC_KEY_HERE";
                endpoint   = "1.2.3.4:51820";  # Mullvad server
                allowedIPs = [ "0.0.0.0/0" ];
                persistentKeepalive = 25;
              }
            ];
          };
        };

      # applications
      environment.systemPackages = with pkgs; [ qbittorrent-nox ];

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
    };
  };
}