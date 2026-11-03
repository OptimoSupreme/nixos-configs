#### Steam Machine Maintenance ####

{
  config,
  inputs,
  lib,
  ...
}:

{
  imports = [
    ./generic.nix
    inputs.steam-maintenance.nixosModules.default
  ];

  ## Updates Are User Driven (the System Update tile in Steam)
  services.steam-maintenance.enable = true;
  services.steam-maintenance.cacheWorkflow = "cache-${config.networking.hostName}.yml";
  systemd.timers.nixos-upgrade.enable = false;
  nix.gc.automatic = false;
  nix.optimise.automatic = false;
  nix.settings.auto-optimise-store = lib.mkDefault true;
  system.configurationRevision = lib.mkDefault (inputs.self.rev or inputs.self.dirtyRev or null);

  ## Binary Cache (filled by .github/workflows/cache-<host>.yml)
  nix.settings.substituters = [ "https://steam-maintenance.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "steam-maintenance.cachix.org-1:lJcWsv/e8+Oe34s6PuVcc6bX0C7d3Jy8r7HPqLuRkts="
  ];
}

# gamescope only shows windows of processes Steam launched, so the updater UI runs
# as a Steam shortcut (the System Update tile). The weekly prompt stays silent when
# main has not changed. With the daily timer off, a branch deploy on these hosts does
# not revert itself: return them to main by hand.
