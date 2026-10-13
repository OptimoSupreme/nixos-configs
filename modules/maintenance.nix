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
    ## Swap
    zramSwap = {
      enable = lib.mkDefault true;
      memoryMax = lib.mkDefault (8 * 1024 * 1024 * 1024);
      priority = lib.mkDefault 1;
    };

    ## Btrfs Scrub
    services.btrfs.autoScrub.enable = lib.mkDefault hasBtrfs;

    ## Updates (public repo over HTTPS, so the host holds no credential)
    system.autoUpgrade = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault "github:OptimoSupreme/nixos-configs";
      operation = lib.mkDefault "boot";
      dates = lib.mkDefault "10:00";
      randomizedDelaySec = lib.mkDefault "20m";
    };

    ## Store GC and Deduplication
    nix = {
      gc = {
        automatic = lib.mkDefault true;
        dates = lib.mkDefault "weekly";
      };
      optimise = {
        automatic = lib.mkDefault true;
        dates = [ "Mon 01:00" ];
      };
    };
    # nix-collect-garbage has no keep-N; prune the system profile first
    systemd.services.nix-gc.preStart = ''
      ${config.nix.package}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +5
    '';

    ## Flakes
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
