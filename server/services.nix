{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ wireguard-tools qbittorrent-nox ];

  # ddclient
  services = {
    ddclient = {
      enable = true;
      protocol    = "cloudflare";
      server      = "api.cloudflare.com/client/v4";
      ssl         = true;
      username    = "token";
      passwordFile = "/srv/secrets/cloudflare-token";
      domains     = [ "questionable.zip" ];
      zone        = "questionable.zip";
      interval = "10m";
    };
  };

  # technitium-dns
  services = {
    technitium-dns-server = {
      enable = true;
      openFirewall = true;
    };
  };

  # wireguard server
  networking = {
    nat = {
      enable = true;
      externalInterface = "enp2s0";
      internalInterfaces = [ "wg0" ];
    };
    firewall = {
      interfaces = {
        enp2s0.allowedUDPPorts = [ 443 ];
      };
    };
    wireguard.interfaces = {
      wg0 = {
        ips = [ "10.69.69.1/24" ];
        listenPort = 443;
        postSetup = ''
          ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.69.69.0/24 -o enp2s0 -j MASQUERADE
        '';
        postShutdown = ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.69.69.0/24 -o enp2s0 -j MASQUERADE
        '';
        privateKeyFile = "/srv/secrets/wireguard-keys/private";
        peers = [
          {
            # Justin's Phone
            publicKey = "JsQ/MwVgher/ZGzBh38ZRP+Bahp7sUri+unDhUs+FXI=";
            endpoint = "questionable.zip:443";
            allowedIPs = [ "10.69.69.2/32" ];
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };

  # media stack (under construction)
  users.groups.media = {};
  users.users.media = {
    isSystemUser = true;
    group = "media";
  };
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
  ];
  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-sdk-6.0.428"
    "aspnetcore-runtime-6.0.36"
  ];
  systemd.services.qbittorrent = {
    description = "qBittorrent-nox Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
      Restart = "on-failure";
      User = "media";
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

  # shairport-sync (under construction)
  # environment = {
  #   systemPackages = with pkgs; [
  #     alsa-utils
  #     shairport-sync-airplay2
  #   ];
  # };
  # services = {
  #   pipewire = {
  #     enable = true;
  #     alsa = {
  #       enable = true;
  #       support32Bit = true;
  #     };
  #     pulse.enable = true;
  #   };
  # };
  # systemd.services = {
  #   outdoor-speakers = {
  #     description = "Outdoor speakers shairport-sync instance";
  #     wantedBy = [ "multi-user.target" ];
  #     serviceConfig = {
  #       ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/outdoor_speakers.conf";
  #     };
  #   };
  #   dining-room = {
  #     description = "Dining room shairport-sync instance";
  #     wantedBy = [ "multi-user.target" ];
  #     serviceConfig = {
  #       ExecStart = "${pkgs.shairport-sync}/bin/shairport-sync -c /srv/shairport-sync/dining_room.conf";
  #     };
  #   };
  # };

  # docker
  virtualisation.docker.enable = true;
}
