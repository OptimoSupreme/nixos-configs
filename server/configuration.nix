{ config, lib, pkgs, ... }:

{
  # Imports
  imports =
    [
      ./hardware-configuration.nix
      ./network_services.nix
      # ./servarr.nix
      # ./shairport-sync.nix
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
      interface = "enp2s0";
      address = "10.0.0.1";
    };
    nameservers = [ "1.1.1.1" ];
    nat = {
      enable = true;
      externalInterface = "enp2s0";
      internalInterfaces = [ "wg0" ];
    };
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

  # Modules
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  services = {
    openssh.enable = true;
    fwupd.enable = true;
  };
  virtualisation.docker.enable = true;

  # Environment and packages
  nixpkgs.config.allowUnfree = true;
  environment = {
    systemPackages = with pkgs; [
      btrfs-progs
      git
    ];
  };

  # User configuration
  users.users = {
    justin = {
      isNormalUser = true;
      description = "Justin";
      extraGroups = [ "wheel" ];
      packages = with pkgs; [ microfetch ];
    };
  };
}
