#### NixOS Powered Steam Machine ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    inputs.jovian.nixosModules.default
    ../../../modules/maintenance.nix
  ];

  ## GPU: AMD (nothing to add)

  ## Firmware: the amdgpu blobs
  hardware.enableRedistributableFirmware = true;

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "quiet" ];

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

  ## Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  ## SSH: the only way in, always on
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
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
