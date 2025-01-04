{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Boot configuration
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };
  };

  # Connectivity
  hardware.bluetooth.enable = false;
  networking.interfaces.enu1u1u1.useDHCP = false;

  networking = {
    hostName = "vics-pi";
    firewall.enable = true;
    nameservers = [ "1.1.1.1" ];
    wireless = {
      enable = true;
      networks = {
        "Airnet" = {
          psk = "over9000";
        };
      };
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

  # Modules and services
  zramSwap = {
    enable = true;
    memoryPercent = 25;
    priority = 5;
  };
  swapDevices = [{
    device = "/swapfile";
    size = 4 * 1024;
    priority = 1;
  }];

  services.openssh.enable = true;
  virtualisation.docker.enable = true;

  # Environment and packages
  nixpkgs.config.allowUnfree = true;

  # User configuration
  users.users = {
    justin = {
      isNormalUser = true;
      description = "Justin";
      extraGroups = [ "wheel" ];
      password = "password";
      packages = with pkgs; [
        btop
        git
        microfetch
        zellij
      ];
    };
  };
}
