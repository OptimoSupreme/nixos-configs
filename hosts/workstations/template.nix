#### General Purpose Workstation Template ####

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    # ../../../modules/maintenance.nix          # Maintenance
    # ../../../modules/fastfetch.nix            # Fastfetch
    # ../../../modules/firefox.nix              # Firefox Config
    # ../../../modules/btrfs_snapshots.nix      # BTRFS Snapshots
    # ../../../modules/tpm_decryption.nix       # TPM Decryption Setup Script
    # ../../../modules/general_environment.nix  # General Purpose Environment
    # ../../../modules/personal_environment.nix # Personal Environment
  ];

  ## Boot
  ## UEFI
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.systemd-boot.configurationLimit = 10;
  # boot.loader.efi.canTouchEfiVariables = true;

  ## Legacy BIOS
  # boot.loader.grub.enable = true;
  # boot.loader.grub.device = "/dev/sda"; # whole disk, not a partition
  # boot.loader.grub.configurationLimit = 10;

  ## Kernel
  # boot.kernelPackages = pkgs.linuxPackages;        # Latest LTS
  # boot.kernelPackages = pkgs.linuxPackages_latest; # Latest Stable

  ## Swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 1;
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 8 * 1024;
      priority = 0;
    }
  ];

  ## Networking - make sure hostname matches flake.nix
  networking = {
    networkmanager.enable = true;
    hostName = "changeme";
  };

  ## Timezone and Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  ## User Account
  users.users.changeme = {
    isNormalUser = true;
    description = "Changeme";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  ## Select GPU's
  ## AMD (nothing to add)

  ## Intel (choose one)
  # hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ]; # Broadwell and newer
  # hardware.graphics.extraPackages = with pkgs; [ intel-vaapi-driver ]; # Haswell and older

  ## Nvidia (all three)
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia.open = true; # true on Turing (GTX 16xx / RTX 20xx) and newer, false before
  # nixpkgs.config.allowUnfree = true;

  ## Nvidia PRIME (Also enable nvidia and intel, update bus IDs from `lspci -D -d ::03xx`)
  # hardware.nvidia.prime.offload.enable = true;
  # hardware.nvidia.prime.offload.enableOffloadCmd = true;
  # hardware.nvidia.prime.intelBusId = "PCI:0@0:2:0";
  # hardware.nvidia.prime.nvidiaBusId = "PCI:1@0:0:0";
  # hardware.nvidia.powerManagement.finegrained = true;

  system.stateVersion = "26.05";
}
