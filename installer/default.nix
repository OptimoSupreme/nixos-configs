#### Installation Media ####

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"

    ## Select Modules
    ../modules/fastfetch.nix            # Fastfetch
    ../modules/firefox.nix              # Firefox Config
    ../modules/personal_environment.nix # Personal Environment
  ];

  ## Kernel options, Default LTS with ZFS or Latest Stable
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

  ## Networking - make sure hostname matches flake.nix
  networking = {
    networkmanager.enable = true;
    hostName = "installer";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  ## Pinned apps
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

  ## Don't install flatpaks from personal_environment
  systemd.services.flatpak-apps.enable = false;

  ## Override plain duplicate Firefox
  environment.systemPackages = [ (lib.hiPrio config.programs.firefox.finalPackage) ];

  ## Clone the repo into the live user's home once the network is up, so the
  ## stick always starts from the latest main. Retries until it succeeds, so
  ## joining WiFi after login is fine.
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

  ## Enable SSH
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  ## Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
