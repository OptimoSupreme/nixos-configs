#### NixOS Powered Steam Deck ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    inputs.jovian.nixosModules.default
    ../../../modules/maintenance/steam.nix
  ];

  ## Hardware: Steam Deck (Valve kernel and drivers, firmware, audio DSP, controller)
  jovian.devices.steamdeck = {
    enable = true;
    autoUpdate = true; # BIOS and controller firmware, as SteamOS does
  };

  ## Firmware: CPU microcode (Jovian ships the rest)
  hardware.enableRedistributableFirmware = true;

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;

  ## Boot Splash
  boot.consoleLogLevel = 3;
  boot.plymouth = {
    enable = true;
    theme = "steamos";
    themePackages = [ pkgs.jovianPackages.steamdeck-hw-theme ];
  };

  ## Kernel: Valve's, from the Steam Deck module
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

  ## Networking
  networking = {
    networkmanager.enable = true;
    hostName = "smeagol";
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

  ## Audio: PipeWire comes from the Steam Deck module
  security.rtkit.enable = true;

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
