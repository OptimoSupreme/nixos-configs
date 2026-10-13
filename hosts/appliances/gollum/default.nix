#### NixOS Powered Steam Machine ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    inputs.jovian.nixosModules.default
    ../../../modules/maintenance.nix
    ../../../modules/appliance.nix
  ];

  ## GPU: AMD (nothing to add)

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## Swap (the fleet block in maintenance.nix replaces the SteamOS one)
  jovian.steamos.enableZram = false;

  ## Networking
  networking = {
    networkmanager.enable = true;
    hostName = "gollum";
  };

  ## Timezone
  time.timeZone = "America/New_York";

  ## User Account
  users.users.justin = {
    isNormalUser = true;
    description = "Justin";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  ## Steam Gaming Mode from boot
  nixpkgs.config.allowUnfree = true;
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "justin";
    desktopSession = "gamescope-wayland";
  };
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  system.stateVersion = "26.05";
}
