#### Workstation Template ####

{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    # inputs.nixos-hardware.nixosModules.changeme   # Board quirks (github.com/NixOS/nixos-hardware)
    # ../../../modules/maintenance/generic.nix      # Updates, GC, scrub, flakes (one maintenance module per host)
    # ../../../modules/maintenance/wake_updates.nix # The same, waking Sun 03:00 to upgrade, GC and reboot (desktops left on)
    # ../../../modules/sleep_then_shutdown.nix      # Power off after two hours asleep (laptops, saves battery)
    # ../../../modules/firefox.nix                  # Firefox policies
    # ../../../modules/btrfs_snapshots.nix          # Snapper on /home
    # ../../../modules/tpm_decryption.nix           # TPM unlock enrollment script
    # ../../../modules/secure_boot.nix              # Lanzaboote (needs the UEFI lines below)
    # ../../../modules/client_environment.nix       # Client user environment
    # ../../../modules/personal_environment.nix     # Personal user environment (add home_patch, work_patch or both)
    # ../../../modules/home_patch.nix               # Home apps (Discord, Steam, Spotify, LocalSend, GIMP, ...) and the home server
    # ../../../modules/work_patch.nix               # CAC, Chromium, Slack, Zoom
  ];

  ## GPU (choose one; a nixos-hardware board module may already set early KMS)
  ## AMD (ROCm compute is optional)
  # hardware.amdgpu.initrd.enable = true; # early KMS
  # hardware.amdgpu.opencl.enable = true;

  ## Intel (choose one VA-API driver)
  # boot.initrd.kernelModules = [ "i915" ]; # early KMS; "xe" on Lunar Lake, Battlemage and newer
  # hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ]; # Broadwell and newer
  # hardware.graphics.extraPackages = with pkgs; [ intel-vaapi-driver ]; # Haswell and older

  ## Nvidia (all five, open module too)
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia.open = true; # true on Turing (GTX 16xx / RTX 20xx) and newer, false before
  # hardware.nvidia.modesetting.enable = true; # adds nvidia-drm.modeset=1 and fbdev=1
  # boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ]; # early KMS
  # nixpkgs.config.allowUnfree = true;

  ## Hybrid Graphics (Nvidia PRIME) (also enable Nvidia and Intel; early KMS from the iGPU line only; bus IDs from `lspci -D -d ::03xx`)
  # hardware.nvidia.prime.offload.enable = true;
  # hardware.nvidia.prime.offload.enableOffloadCmd = true;
  # hardware.nvidia.prime.intelBusId = "PCI:0@0:2:0";
  # hardware.nvidia.prime.nvidiaBusId = "PCI:1@0:0:0";
  # hardware.nvidia.powerManagement.finegrained = true;

  ## Hybrid Graphics (any vendor) (adds "Launch using Discrete Graphics Card")
  # services.switcherooControl.enable = true;

  ## Intel CPU
  # services.thermald.enable = true;

  ## Boot (choose one)
  ## UEFI
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.systemd-boot.configurationLimit = 10; # measured boot (secure_boot.nix on LUKS) sets 4
  # boot.loader.efi.canTouchEfiVariables = true;

  ## Legacy BIOS
  # boot.loader.grub.enable = true;
  # boot.loader.grub.device = "/dev/sda"; # whole disk, not a partition
  # boot.loader.grub.configurationLimit = 10;

  ## Kernel (choose one)
  # boot.kernelPackages = pkgs.linuxPackages;        # LTS
  # boot.kernelPackages = pkgs.linuxPackages_latest; # Latest stable

  ## Swapfile (if zram alone isn't enough)
  swapDevices = [
    {
      device = "/swapfile";
      size = 8 * 1024;
      priority = 0;
    }
  ];

  ## Networking (hostName must match the flake attribute)
  networking.hostName = "changeme";

  ## Timezone
  # time.timeZone = "America/New_York"; # pin a zone instead of GNOME setting it from location

  ## User Account
  users.users.changeme = {
    isNormalUser = true;
    description = "Changeme";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  system.stateVersion = "26.05";
}
