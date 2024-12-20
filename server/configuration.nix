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

  # Raid
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
      interfaces."enp2s0".allowedUDPPorts = [ 7777 53 ];
    };
  };

  # Time and locale settings
  time = {
    timeZone = "US/Eastern";
  };
  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

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
  };

  # virtualisation.oci-containers = {
  #   backend = "docker";
  #   containers.satisfactory = {
  #     image = "wolveix/satisfactory-server:latest";
  #     containerName = "satisfactory";
  #     hostname = "satisfactory";
  #     restartPolicy = "unless-stopped";
  #     volumes = [ "/srv/satisfactory:/config" ];
  #     environment = {
  #       MAXPLAYERS = "4";
  #       PGID = "995";
  #       PUID = "999";
  #       ROOTLESS = "false";
  #       STEAMBETA = "false";
  #     };
  #     stopSignal = "SIGINT";
  #     ports = [
  #       "7777:7777/udp"
  #       "7777:7777/tcp"
  #     ];
  #     extraOptions = [
  #       "--memory=12G"
  #       "--memory-reservation=6G"
  #     ];
  #   };
  # };

  # Modules
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Environment and packages
  nixpkgs.config.allowUnfree = true;
  environment = {
    systemPackages = with pkgs; [
      btrfs-progs
      git
      tree
    ];
  };

  # User configuration
  users = {
    users = {
      justin = {
        isNormalUser = true;
        description = "Justin";
        extraGroups = [ "networkmanager" "wheel" ];
      };
    };
  };
}
