#### NixOS Powered Steam Machine ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    inputs.jovian.nixosModules.default
    ../../../modules/maintenance/steam.nix
  ];

  ## GPU: AMD (nothing to add)

  ## Firmware: the amdgpu blobs
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

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
    "amdgpu.dcfeaturemask=0x402" # HDMI 2.1 FRL for 4K120, see TODO.md
  ];
  boot.kernelPatches = [
    {
      name = "hpo-vpg-afmt-dcn302"; # HDR and audio over FRL, see TODO.md
      patch = ./0001-drm-amd-display-use-the-HPO-VPG-AFMT-instance-on-DCN-3.0.2.patch;
    }
  ];

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

  ## Decky Loader (plugins run as the Steam user: Steamcord keeps a Discord session per user)
  jovian.decky-loader = {
    enable = true;
    user = "justin";
  };

  ## Steamcord Prerequisites (the plugin itself is installed by hand, see below)
  environment.systemPackages = with pkgs; [
    vesktop # native client, so no Flatpak
    pulseaudio # pactl, game audio in screen share
    ffmpeg # screen share preview
  ];

  system.stateVersion = "26.05";
}

# Steamcord is not on the Decky store, so install it yourself once: Decky settings,
# Developer Mode, Install plugin from URL with
# https://github.com/Necrosiak/Steamcord/releases/latest/download/Steamcord.zip,
# accept the third-party warning, then log in by QR code. It updates itself after that.
