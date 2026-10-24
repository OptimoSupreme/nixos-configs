#### My Work Laptop ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen # confirm with `sudo dmidecode -s system-version`
    ../../../modules/maintenance.nix
    ../../../modules/firefox.nix
    ../../../modules/tpm_decryption.nix
    ../../../modules/secure_boot.nix
    ../../../modules/personal_environment.nix
    ../../../modules/work_patch.nix
  ];

  ## GPU: Intel (driver, VA-API and early KMS come from the nixos-hardware module)

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## Networking
  networking.hostName = "wormtongue";

  ## User Account
  users.users.justin = {
    isNormalUser = true;
    description = "Justin";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  ## Work Git Identity
  home-manager.users.justin.programs.git.settings.user.email = "justin.ward@elastic.co";

  system.stateVersion = "26.05";
}
