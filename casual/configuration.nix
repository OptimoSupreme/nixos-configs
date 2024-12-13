{ config, pkgs, ... }:

{
  # Imports
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # kernelPackages = pkgs.linuxPackages_latest; # latest LTS kernel is default, uncomment if you require the latest kernel
    initrd = {
      systemd.enable = true;
      verbose = false;
    };
    plymouth.enable = true;
    consoleLogLevel = 0;
    kernelParams = [
      "boot.shell_on_fail"
      "loglevel=3"
      "quiet"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "splash"
      "udev.log_priority=3"
    ];
    loader.timeout = 0;
  };

  # Hardware configuration
  hardware = {
    graphics.enable = true;
    pulseaudio.enable = false;
  };

  # Networking configuration
  networking = {
    networkmanager.enable = true;
    hostName = "hostname";
  };

  # Time and locale settings
  time = {
    timeZone = "US/Eastern";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Services
  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      excludePackages = [ pkgs.xterm ];
    };
    printing.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    flatpak.enable = true;
  };

  # System settings
  system = {
    autoUpgrade = {
      enable = true;
      allowReboot = false;
    };
    stateVersion = "24.11";
  };

  # User configuration
  users = {
    users = {
      username = {
        isNormalUser = true;
        description = "Pretty Username";
        extraGroups = [ "networkmanager" "wheel" ];
      };
    };
  };

  # Environment and packages
  environment = {
    systemPackages = with pkgs; [
      gnome-software
      onlyoffice-desktopeditors
      spotify
    ];
    gnome.excludePackages = with pkgs; [
      epiphany
      geary
      gnome-contacts
      gnome-music
      gnome-tour
      yelp
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # Modules
  programs = {
    firefox.enable = true;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 40;
  };
}
