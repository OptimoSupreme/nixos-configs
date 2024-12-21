{ config, pkgs, ... }:

{
  # Imports
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true; # comment if legacy boot system
      efi.canTouchEfiVariables = true; # comment if legacy boot system
      # grub.enable = true; # uncomment for legacy boot system
      # grub.device = "/dev/sda"; # uncomment for legacy boot system, use appropriate disk
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
  time.timeZone = "US/Eastern";
  i18n.defaultLocale = "en_US.UTF-8";

  # Maintenance automation
  system = {
    autoUpgrade = {
      enable = true;
      dates = "Tue 03:00";
      persistent = true;
      allowReboot = false;
    };
    stateVersion = "24.11";
  };
  nix.gc = {
    automatic = true;
    dates = "Tue 03:00";
    options = "--delete-older-than +7";
    persistent = true;
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
    fwupd.enable = true;
  };

  # Modules
  programs = {
    firefox.enable = true;
  };
  zramSwap = {
    enable = true;
    memoryPercent = 40;
  };

  # Environment and packages
  nixpkgs.config.allowUnfree = true;
  environment = {
    systemPackages = with pkgs; [
      gnome-software
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

  # User configuration
  users.users = {
    username = {
      isNormalUser = true;
      description = "Pretty Username"; # Update with real pretty username
      extraGroups = [ "networkmanager" "wheel" ];
    };
  };

  # Activation scripts
  system.activationScripts = {
    addFlathub = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
    updateFlatpaks = ''
      ${pkgs.flatpak}/bin/flatpak update
    '';
  };
}
