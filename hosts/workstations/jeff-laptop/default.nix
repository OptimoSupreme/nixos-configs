#### Jeff's HP Laptop ####

{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix          # Maintenance
    ../../../modules/fastfetch.nix            # Fastfetch
    ../../../modules/firefox.nix              # Firefox Config
    ../../../modules/btrfs_snapshots.nix      # BTRFS Snapshots
    ../../../modules/tpm_decryption.nix       # TPM Decryption Setup Script
    ../../../modules/general_environment.nix  # General Purpose Environment
  ];

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages;        # Latest LTS

  ## Swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 1;
  };

  ## Networking - make sure hostname matches flake.nix
  networking = {
    networkmanager.enable = true;
    hostName = "jeff-laptop";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  ## User Account
  users.users.jeff = {
    isNormalUser = true;
    description = "Jeff";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  ## Select GPU's
  ## AMD (nothing to add)

  ## Intel (choose one)
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ]; # Broadwell and newer

  ## GPU Fix
  services.udev.extraRules = builtins.readFile ./60-amdgpu-no-d3cold.rules;

  ## Disabled SSH Service - Temporary while developing
  services.openssh.enable = true;
  systemd.services.sshd.wantedBy = lib.mkForce [ ];

  system.stateVersion = "26.05";
}
