
#### My Desktop ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix          # Maintenance
    ../../../modules/fastfetch.nix            # Fastfetch
    ../../../modules/firefox.nix              # Firefox Config
    ../../../modules/btrfs_snapshots.nix      # BTRFS Snapshots
    ../../../modules/personal_environment.nix # Personal Environment
  ];

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest; # Latest Stable

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
    hostName = "balrog";
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

  ## Select GPU's
  ## AMD (nothing to add)

  ## Corectrl
  programs.corectrl.enable = true;
  users.groups.corectrl.members = [ "justin" ];
  environment.etc."xdg/autostart/org.corectrl.CoreCtrl.desktop".source =
    "${pkgs.corectrl}/share/applications/org.corectrl.CoreCtrl.desktop";

  system.stateVersion = "26.05";
}
