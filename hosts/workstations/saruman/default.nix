#### My Basement Gaming Desktop ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/fastfetch.nix
    ../../../modules/firefox.nix
    ../../../modules/secure_boot.nix
    ../../../modules/personal_environment.nix
  ];

  ## GPU: AMD (nothing to add)

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## Swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 1;
  };

  ## Networking
  networking = {
    networkmanager.enable = true;
    hostName = "saruman";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Windows dual boot
  i18n.defaultLocale = "en_US.UTF-8";

  ## User Account
  users.users.justin = {
    isNormalUser = true;
    description = "Justin";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  ## CoreCtrl
  programs.corectrl.enable = true;
  users.groups.corectrl.members = [ "justin" ];
  environment.etc."xdg/autostart/org.corectrl.CoreCtrl.desktop".source =
    "${pkgs.corectrl}/share/applications/org.corectrl.CoreCtrl.desktop";

  system.stateVersion = "26.05";
}
