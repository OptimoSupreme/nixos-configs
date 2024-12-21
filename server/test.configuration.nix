{ config, lib, pkgs, ... }:

{
  # Imports
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Filesystems
  fileSystems."/srv" = {
    device = "/dev/disk/by-uuid/db8f6060-73d6-4440-9692-50d04fd15f65";
    fsType = "btrfs";
    options = [ "noatime" "compress=zstd" ];
  };

  # Networking configuration
  networking = {
    networkmanager.enable = true;
    hostName = "morgoth";
    firewall = {
      interfaces."enp2s0".allowedTCPPorts = [ 7777 53 5380 53443 ];
      interfaces."enp2s0".allowedUDPPorts = [ 7777 53 443 ];
      allowedUDPPorts = [ 51820 ];
      interfaces."wg0".allowedForwardTo = [ "enp2s0" ];
      interfaces."enp2s0".allowedForwardTo = [ "wg0" ];
    };
    enableIPv4Forwarding = true;
  };

  # Time and locale settings
  time.timeZone = "US/Eastern";
  i18n.defaultLocale = "en_US.UTF-8";

  # Maintenance automation
  system = {
    autoUpgrade = {
      enable = true;
      dates = "Tue 03:00";
      persistent = true;
      allowReboot = true;
    };
    stateVersion = "24.11";
  };
  nix.gc = {
    automatic = true;
    dates = "Tue 03:30";
    options = "--delete-older-than +7";
    persistent = true;
  };

  # Services
  services = {
    openssh.enable = true;
    fwupd.enable = true;
    technitium-dns-server.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    wireguard.interfaces = {
      wg0 = {
        addresses = [ "10.8.0.1/24" ];
        listenPort = 443;

        # Point to the previously generated private key
        privateKeyFile = "/var/lib/wireguard/wg0.key";

        # Add peers. You can add multiple peers for different devices.
        # Replace the publicKey below with your peer's public key (from wg genkey on the peer side).
        # allowedIPs indicate what IP the peer will use inside the VPN.
        # If you also want the peer to be able to access your LAN (e.g., 192.168.1.0/24), 
        # you can add that to the allowedIPs on the peer side (client config).
        peers = [
          {
            publicKey = "REPLACE_WITH_PEER_PUBLIC_KEY";
            allowedIPs = [ "10.8.0.2/32" ];
          }
        ];
      };
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.satisfactory = {
      image = "wolveix/satisfactory-server:latest";
      hostname = "satisfactory";
      volumes = [ "/srv/freeloader/satisfactory:/config" ];
      environment = {
        MAXPLAYERS = "4";
        PGID = "995";
        PUID = "999";
        ROOTLESS = "false";
        STEAMBETA = "false";
      };
      ports = [
        "7777:7777/udp"
        "7777:7777/tcp"
      ];
      extraOptions = [
        "--memory=12G"
        "--memory-reservation=6G"
      ];
    };
  };

  # Modules
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Environment and packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    btrfs-progs
    git
    tree
  ];

  # User configuration
  users.users = {
    justin = {
      isNormalUser = true;
      description = "Justin";
      extraGroups = [ "networkmanager" "wheel" ];
    };
  };
}
