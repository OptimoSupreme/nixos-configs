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
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
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
    hostName = "morgoth";
    interfaces.enp2s0 = {
      ipv4.addresses = [{
        address = "10.0.0.45";
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = "10.0.0.1";
      interface = "enp2s0";
    };
    nameservers = [ "1.1.1.1" ];
    firewall.enable = true;
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
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    technitium-dns-server = {
      enable = true;
      openFirewall = true;
    };
    audiobookshelf = {
      enable = true;
      openFirewall = true;
      port = 8000;
      host = "10.0.0.45";
    };
  };
  
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
  
  virtualisation.docker.enable = true;

  # Modules
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Environment and packages
  nixpkgs.config.allowUnfree = true;
  environment = {
    systemPackages = with pkgs; [
      alsa-utils
      btrfs-progs
      git
      shairport-sync-airplay2
      tree
    ];
  };

  # User configuration
  users.users = {
    justin = {
      isNormalUser = true;
      description = "Justin";
      extraGroups = [ "wheel" ];
      packages = with pkgs; [
        microfetch
        zellij
      ];
    };
  };
}
