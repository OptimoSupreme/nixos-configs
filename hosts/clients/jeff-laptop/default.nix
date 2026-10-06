#### Jeff's HP Laptop ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/fastfetch.nix
    ../../../modules/firefox.nix
    ../../../modules/btrfs_snapshots.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/general_environment.nix
  ];

  ## GPU: Intel
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  ## Keep the AMD dGPU out of D3cold
  services.udev.extraRules = builtins.readFile ./60-amdgpu-no-d3cold.rules;

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

  ## Networking
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
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  system.stateVersion = "26.05";
}
