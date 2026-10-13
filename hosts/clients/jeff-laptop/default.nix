#### Jeff's HP Laptop ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/firefox.nix
    ../../../modules/btrfs_snapshots.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/secure_boot.nix
    ../../../modules/client_environment.nix
  ];

  ## GPU: Intel
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  ## Keep the AMD dGPU out of D3cold
  services.udev.extraRules = builtins.readFile ./60-amdgpu-no-d3cold.rules;

  ## Hybrid Graphics (any vendor)
  services.switcherooControl.enable = true;

  ## Intel CPU
  services.thermald.enable = true;

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages; # LTS

  ## Networking
  networking.hostName = "jeff-laptop";

  ## User Account
  users.users.jeff = {
    isNormalUser = true;
    description = "Jeff";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  system.stateVersion = "26.05";
}
