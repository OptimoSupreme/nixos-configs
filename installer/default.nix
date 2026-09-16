#### Installation Media ####

{ config, lib, pkgs, inputs, modulesPath, ... }:

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

  ## Copy repo to installation media (cleanSource drops .git, which a path: build carries)
  isoImage.contents = [
    { source = lib.cleanSource inputs.self; target = "/nixos-configs"; }
  ];

  ## Copy repo to home
  systemd.services.nixos-configs-home = {
    description = "Copy nixos-configs into the live user's home";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    unitConfig.ConditionPathExists = "!/home/nixos/nixos-configs";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      cp -r --no-preserve=mode /iso/nixos-configs /home/nixos/nixos-configs
      chown -R nixos:users /home/nixos/nixos-configs
    '';
  };

  ## Enable SSH
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  ## Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ## Locked nixpkgs in the image, so the repo copy evaluates offline
  system.extraDependencies = [ inputs.nixpkgs.outPath ];

  system.stateVersion = "26.05";
}
