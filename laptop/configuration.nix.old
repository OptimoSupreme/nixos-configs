{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
  boot.loader.timeout = 0;

  hardware.graphics.enable = true;

  # networking
  networking.networkmanager.enable = true;
  networking.hostName = "nazgul";


  # timezone
  time.timeZone = "US/Eastern";

  # locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
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

  # X11 keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # automatic upgrades
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  # services
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.printing.enable = true;
  services.fprintd.enable = true;
  services.pcscd.enable = true;
  # services.openssh.enable = true;
  services.xserver.excludePackages = [ pkgs.xterm ];


  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # user
  users.users.justin = {
    isNormalUser = true;
    description = "Justin";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      microfetch
      git
      vscode
      gnome-boxes
      slack
      zoom-us
      spotify
      telegram-desktop
      discord
      onlyoffice-desktopeditors
      bottles
      dolphin-emu
      gimp
      alpaca
      localsend
    ];
  };

  # modules
  zramSwap.enable = true;
  zramSwap.memoryPercent = 25;
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # system packages
  environment.systemPackages = with pkgs; [
    nerdfonts
    opensc # cac support
    ccid # cac support
  ];

  environment.gnome.excludePackages = (with pkgs; [
    gnome-maps
    gnome-contacts
    gnome-weather
    gnome-clocks
    gnome-tour
    gnome-music
    epiphany
    geary
    yelp
  ]);

  # nonfree packages
  nixpkgs.config.allowUnfree = true;

  # system state
  system.stateVersion = "24.11";

}
