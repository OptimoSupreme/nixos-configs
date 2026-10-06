#### System Maintenance ####

{ config, lib, ... }:

let
  hasBtrfs = lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems);
in
{
  ## Pass TRIM through LUKS so the weekly fstrim reaches the SSD
  options.boot.initrd.luks.devices = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.allowDiscards = lib.mkDefault true;
      }
    );
  };

  config = {
    ## Btrfs Scrub
    services.btrfs.autoScrub.enable = hasBtrfs;

    ## Updates (public repo over HTTPS, so the host holds no credential)
    system.autoUpgrade = {
      enable = true;
      flake = "github:OptimoSupreme/nixos-configs";
      operation = lib.mkDefault "boot";
      dates = lib.mkDefault "10:00";
      randomizedDelaySec = "20m";
      persistent = true;
      allowReboot = false;
    };

    ## Store GC and Deduplication
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

    ## Flakes
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
