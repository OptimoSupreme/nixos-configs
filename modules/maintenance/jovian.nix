#### Jovian Maintenance ####

{
  config,
  inputs,
  lib,
  ...
}:

let
  hasBtrfs = lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems);
in
{
  imports = [ inputs.steam-maintenance.nixosModules.default ];

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
    services.btrfs.autoScrub.enable = lib.mkDefault hasBtrfs;

    ## Updates Are User Driven (the System Update tile in Steam)
    services.steam-maintenance.enable = true;
    services.steam-maintenance.cacheWorkflow = "cache-${config.networking.hostName}.yml";
    system.autoUpgrade = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault "github:OptimoSupreme/nixos-configs";
      operation = lib.mkDefault "boot";
    };
    systemd.timers.nixos-upgrade.enable = false;
    nix.settings.auto-optimise-store = lib.mkDefault true;
    system.configurationRevision = lib.mkDefault (inputs.self.rev or inputs.self.dirtyRev or null);
    # nix-collect-garbage has no keep-N; prune the system profile first
    systemd.services.nix-gc.preStart = ''
      ${config.nix.package}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +5
    '';

    ## Binary Cache (filled by .github/workflows/cache-<host>.yml)
    nix.settings.substituters = [ "https://steam-maintenance.cachix.org" ];
    nix.settings.trusted-public-keys = [
      "steam-maintenance.cachix.org-1:lJcWsv/e8+Oe34s6PuVcc6bX0C7d3Jy8r7HPqLuRkts="
    ];

    ## Flakes
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}

# gamescope only shows windows of processes Steam launched, so the updater UI runs
# as a Steam shortcut (the System Update tile). The weekly prompt stays silent when
# main has not changed. With the daily timer off, a branch deploy on these hosts does
# not revert itself: return them to main by hand.
