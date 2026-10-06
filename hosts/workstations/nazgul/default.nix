#### My Laptop ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/fastfetch.nix
    ../../../modules/firefox.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/secure_boot.nix
    ../../../modules/personal_environment.nix
  ];

  ## GPU: AMD (nothing to add)

  ## Screenshot Key Override
  services.udev.extraHwdb = ''
    evdev:atkbd:dmi:bvn*:bvr*:bd*:svnHP:pnHPEliteBook84514inchG10*:*
     KEYBOARD_KEY_68=sysrq
  '';

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
    hostName = "nazgul";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
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

  system.stateVersion = "26.05";
}
