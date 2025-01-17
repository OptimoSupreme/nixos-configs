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

  # Time and locale settings
  time.timeZone = "US/Eastern";
  i18n.defaultLocale = "en_US.UTF-8";

  # User configuration
  users.users = {
    justin = {
      isNormalUser = true;
      description = "Justin";
      extraGroups = [ "wheel" ];
      packages = with pkgs; [ "microfetch" "git" ];
    };
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

  # Enable zram
  # nixpkgs.config.allowUnfree = true; # probably not needed here
  services.openssh.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  ####################### Network Configuration #######################

  # Interfaces
  networking = {
    hostName = "sauron";
    interfaces = {
      # wan
      eth0 = {
        useDHCP = true;
      };
      # lan
      eth1 = {
      ipv4.addresses = [{
        address = "10.0.0.1";
        prefixLength = 24;
      }];

    };
    defaultGateway.interface = eth0;
    };
    nameservers = [ "10.0.0.1" ];
  };

  # Firewall
  networking.firewall = {
    enable = true;
    interfaces.eth1.allowedTCPPorts = [ 22 ]
  };

  # DHCP Server
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    dhcp = {
      enable = true;
      range = {
        start = "10.0.0.20";
        end = "10.0.0.254";
        leaseTime = "12h";
      };
      options = [
        "option:dns-server,10.0.0.1"
        "option:router,10.0.0.1"
      ];
    };
  };

  # NAT
  networking = {
    nat = {
      enable = true;
      externalInterface = "eth0";
      internalInterfaces = [ "eth1" ];
    };
  };

  # DNS Server
  services = {
    technitium-dns-server = {
      enable = true;
      openFirewall = true;
    };
  };

  # UPnP
  services.miniupnpd = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "eth1" ];
  };

#####################################################################
}