#### System Maintenance ####

{ config, lib, ... }:

let
  hasBtrfs = lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems);
in
{
  # Monthly btrfs scrub
  services.btrfs.autoScrub.enable = hasBtrfs;

  # System updates: pull the public repo over HTTPS, so the host holds no
  # credential for it
  system.autoUpgrade = {
    enable = true;
    flake = "github:OptimoSupreme/nixos-configs";
    operation = lib.mkDefault "boot";
    dates = lib.mkDefault "10:00";
    randomizedDelaySec = "20m";
    persistent = true;
    allowReboot = false;
  };

  # Weekly store GC and deduplication
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    optimise = {
      automatic = true;
      dates = [ "Mon 01:00" ];
    };
  };

  # Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
