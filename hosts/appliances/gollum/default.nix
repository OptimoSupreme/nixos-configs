#### NixOS Powered Steam Machine ####

{ config, inputs, pkgs, ... }:

{
  imports = [
    inputs.jovian.nixosModules.default
    ../../../modules/maintenance.nix # staged upgrades, GC/dedup, scrub, flakes
    ./hardware-configuration.nix
  ];

  ## Boot
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 0;
  };

  ## Kernel
  boot = {
    kernelPackages = pkgs.linuxPackages_latest; # Latest Stable
    kernelParams = [ "quiet" ];
  };

  ## Swap
  jovian.steamos.enableZram = true;

  ## Networking - make sure hostname matches flake.nix
  networking = {
    networkmanager.enable = true;
    hostName = "gollum";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  ## User Account
  users.users.justin = {
    isNormalUser = true;
    description = "Justin";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  ## SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  ## Select GPU's
  ## AMD (nothing to add)

  ## Steam - Jovian-NixOS Gaming Mode straight from boot, no desktop session
  nixpkgs.config.allowUnfree = true;
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "justin";
    desktopSession = "gamescope-wayland";
  };
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  ## Firmware - the amdgpu blobs
  hardware.enableRedistributableFirmware = true;

  ## Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  system.stateVersion = "26.05";
}
