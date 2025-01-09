{ config, pkgs, ... }:

{
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
  environment.systemPackages = with pkgs; [ wireguard-tools ];
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

  # media stack
  services = {
    sonarr = {
      enable = true;
      openFirewall = true;
    };
    radarr = {
      enable = true;
      openFirewall = true;
    };
    lidarr = {
      enable = true;
      openFirewall = true;
    };
    readarr = {
      enable = true;
      openFirewall = true;
    };
    bazarr = {
      enable = true;
      openFirewall = true;
    };
    prowlarr = {
      enable = true;
      openFirewall = true;
    };
    audiobookshelf = {
      enable = true;
      openFirewall = true;
      port = 8000;
      host = "10.0.0.45";
    };
    jellyfin = {
      enable = true;
      openFirewall = true;
      mediaDirectories = [
        { path = "/mnt/media/movies"; name = "Movies"; }
        { path = "/mnt/media/tv"; name = "TV Shows"; }
      ];
    };
    qbittorrent = {
      enable = true;
      dataDir = "/var/lib/qbittorrent";
      webUiPort = 8080;
      settings = {
        "Preferences/Connection/PortRangeMin" = 6881;
        "Preferences/Connection/PortRangeMax" = 6889;
        "Preferences/Bittorrent/MaxActiveDownloads" = 5;
      };
    };
    caddy = {
      enable = true;
      config = ''
        http:// {
          reverse_proxy /tv localhost:8989
          reverse_proxy /movies localhost:7878
          reverse_proxy /music localhost:8686
          reverse_proxy /books localhost:8787
          reverse_proxy /subs localhost:6767
          reverse_proxy /index localhost:9696
          reverse_proxy /watch localhost:8096
        }
      '';
    };
  };

  # shairport-sync
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
