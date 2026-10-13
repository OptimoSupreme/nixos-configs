#### My Basement Gaming Desktop ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/firefox.nix
    ../../../modules/secure_boot.nix
    ../../../modules/personal_environment.nix
    ../../../modules/work_patch.nix # temporary, until balrog arrives
  ];

  ## GPU: AMD (nothing to add)

  ## Intel CPU
  services.thermald.enable = true;

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## Networking
  networking.hostName = "saruman";

  ## Clock
  time.hardwareClockInLocalTime = true; # Windows dual boot

  ## User Account
  users.users.justin = {
    isNormalUser = true;
    description = "Justin";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  ## CoreCtrl
  programs.corectrl.enable = true;
  users.groups.corectrl.members = [ "justin" ];
  environment.etc."xdg/autostart/org.corectrl.CoreCtrl.desktop".source =
    "${pkgs.corectrl}/share/applications/org.corectrl.CoreCtrl.desktop";

  system.stateVersion = "26.05";
}
