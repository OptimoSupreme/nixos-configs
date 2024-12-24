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
    firewall = {
      interfaces."enp2s0".allowedTCPPorts = [ 7777 53 5380 53443 ];
      interfaces."enp2s0".allowedUDPPorts = [ 7777 53 ];
    };
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
  };

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
      btrfs-progs
      git
      tree
    ];
  };

  # User configuration
  users.users = {
    justin = {
      isNormalUser = true;
      description = "Justin";
      extraGroups = [ "wheel" ];
    };
  };
}
