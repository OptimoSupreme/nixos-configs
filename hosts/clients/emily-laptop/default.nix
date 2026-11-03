#### Emily's HP Laptop ####

{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance/daily.nix
    ../../../modules/sleep_then_shutdown.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/secure_boot.nix
    ../../../modules/client_environment.nix
  ];

  ## GPU: AMD
  hardware.amdgpu.initrd.enable = true;

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages; # LTS

  ## Swapfile
  swapDevices = [
    {
      device = "/swapfile";
      size = 2 * 1024;
      priority = 0;
    }
  ];

  ## Networking
  networking.hostName = "emily-laptop";

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
