#### Installation Media ####

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"

    ## Select Modules
    ../modules/firefox.nix
    ../modules/personal_environment.nix
  ];

  ## Kernel: LTS with ZFS by default, latest stable as a boot entry
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
  isoImage.configurationName = lib.mkDefault "(LTS kernel)";
  boot.zfs.forceImportRoot = false;
  specialisation.latest-kernel.configuration = {
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.supportedFilesystems.zfs = false;
    isoImage.configurationName = "(latest kernel)";
  };

  ## Swap
  zramSwap = {
    enable = true;
    memoryMax = 8 * 1024 * 1024 * 1024;
    priority = 1;
  };

  ## Networking
  networking.hostName = "installer";

  ## Timezone
  time.timeZone = "America/New_York";

  ## Pinned Apps
  programs.dconf.profiles.user.databases = lib.mkBefore [
    {
      settings."org/gnome/shell".favorite-apps = [
        "calamares.desktop"
        "gparted.desktop"
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "org.gnome.Ptyxis.desktop"
      ];
    }
  ];

  ## No personal flatpaks or home-manager on the live stick (its user is nixos)
  systemd.services.flatpak-apps.enable = false;
  home-manager.users = lib.mkForce { };

  ## Shadow the ISO's plain Firefox with the configured one
  environment.systemPackages = [ (lib.hiPrio config.programs.firefox.finalPackage) ];

  ## The install guide in the live user's home
  systemd.tmpfiles.rules = [ "L+ /home/nixos/INSTALL.md - - - - ${./README.md}" ];

  ## SSH on at boot (the desktop module turns it off)
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  ## Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
