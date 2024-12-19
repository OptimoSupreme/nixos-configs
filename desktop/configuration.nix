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
    kernelPackages = pkgs.linuxPackages_latest;
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
    hostName = "balrog";
  };

  # Time and locale settings
  time = {
    timeZone = "US/Eastern";
  };
  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  # Services
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "amdgpu" ];
      xkb = {
        layout = "us";
        variant = "";
      };
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      excludePackages = [ pkgs.xterm ];
    };
    printing.enable = true;
    pcscd.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    fwupd.enable = true;
  };

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

  # User configuration
  users = {
    users = {
      justin = {
        isNormalUser = true;
        description = "Justin";
        extraGroups = [ "corectrl" "networkmanager" "wheel" "libvirtd" ];
        packages = with pkgs; [
          alpaca
          bottles
          discord
          dolphin-emu
          easyeffects
          gimp
          git
          gnome-tweaks
          localsend
          nixpkgs-fmt
          microfetch
          onlyoffice-desktopeditors
          ptyxis
          slack
          spotify
          telegram-desktop
          vscode
          zoom-us
          nixpkgs-fmt
        ];
      };
    };
  };

  # Environment and packages
  environment = {
    systemPackages = with pkgs; [
      ccid
      mint-cursor-themes
      nerdfonts
      opensc
    ];
    gnome.excludePackages = with pkgs; [
      epiphany
      geary
      gnome-clocks
      gnome-console
      gnome-contacts
      gnome-maps
      gnome-music
      gnome-tour
      gnome-weather
      yelp
    ];
  };
  nixpkgs.config.allowUnfree = true;

  # Modules
  programs = {
    corectrl.enable = true;
    firefox.enable = true;
    gamemode.enable = true;
    steam.enable = true;
    virt-manager.enable = true;
  };
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  virtualisation.libvirtd.enable = true;
}
