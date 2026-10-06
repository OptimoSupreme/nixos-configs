#### My Desktop ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
    ../../../modules/maintenance.nix
    ../../../modules/fastfetch.nix
    ../../../modules/firefox.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/secure_boot.nix
    ../../../modules/personal_environment.nix
  ];

  ## GPU: AMD, with ROCm for compute
  hardware.amdgpu.opencl.enable = true;

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
    hostName = "balrog";
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

  ## Packages
  environment.systemPackages = with pkgs; [
    rocmPackages.rocminfo
    clinfo
  ];

  system.stateVersion = "26.05";
}
