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
    ../modules/fastfetch.nix
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
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 1;
  };

  ## Networking
  networking = {
    networkmanager.enable = true;
    hostName = "installer";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

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

  ## No personal flatpaks on the live stick
  systemd.services.flatpak-apps.enable = false;

  ## Shadow the ISO's plain Firefox with the configured one
  environment.systemPackages = [ (lib.hiPrio config.programs.firefox.finalPackage) ];

  ## Clone the repo once the network is up (retries, so joining WiFi after login is fine)
  systemd.services.nixos-configs-clone = {
    description = "Clone nixos-configs into the live user's home";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.git ];
    unitConfig = {
      ConditionPathExists = "!/home/nixos/nixos-configs";
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "nixos";
      Restart = "on-failure";
      RestartSec = 15;
    };
    script = ''
      rm -rf /home/nixos/.nixos-configs.tmp
      git clone https://github.com/OptimoSupreme/nixos-configs.git /home/nixos/.nixos-configs.tmp
      mv /home/nixos/.nixos-configs.tmp /home/nixos/nixos-configs
    '';
  };

  ## SSH on at boot (the desktop module turns it off)
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  ## Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
