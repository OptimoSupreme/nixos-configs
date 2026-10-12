#### Emily's HP Laptop ####

{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/secure_boot.nix
    ../../../modules/client_environment.nix
  ];

  ## GPU: AMD (nothing to add)

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages; # LTS

  ## Swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 1;
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 2 * 1024;
      priority = 0;
    }
  ];

  ## Networking
  networking = {
    networkmanager.enable = true;
    hostName = "emily-laptop";
  };

  ## Locale
  i18n.defaultLocale = "en_US.UTF-8";

  ## User Account
  users.users.emily = {
    isNormalUser = true;
    description = "Emily";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  ## Google Chrome
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [ pkgs.google-chrome ];
  programs.dconf.profiles.user.databases = lib.mkBefore [ { keyfiles = [ ./dconf ]; } ];

  system.stateVersion = "26.05";
}
