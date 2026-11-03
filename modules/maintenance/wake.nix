#### Wake Maintenance ####

{
  config,
  lib,
  pkgs,
  ...
}:

let
  hasBtrfs = lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems);
  maintenance = pkgs.writeShellApplication {
    name = "wake-maintenance";
    runtimeInputs = [
      config.systemd.package
      pkgs.coreutils
    ]
    ++ lib.optional config.networking.networkmanager.enable pkgs.networkmanager;
    text = ''
      ${lib.optionalString config.networking.networkmanager.enable "nm-online --quiet --timeout 120 || true"}
      status=0
      for unit in nixos-upgrade nix-gc nix-optimise; do
        systemctl start "$unit.service" || status=1
      done
      if [ "$(readlink -f /nix/var/nix/profiles/system)" != "$(readlink -f /run/booted-system)" ]; then
        systemctl reboot
      fi
      exit "$status"
    '';
  };
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
    services.btrfs.autoScrub.enable = lib.mkDefault hasBtrfs;

    ## Updates (public repo over HTTPS, so the host holds no credential)
    system.autoUpgrade = {
      enable = lib.mkDefault true;
      flake = lib.mkDefault "github:OptimoSupreme/nixos-configs";
      operation = lib.mkDefault "boot";
    };
    systemd.timers.nixos-upgrade.enable = false; # only the weekly window runs it

    ## Weekly Window (upgrade, GC and optimise all wait for it)
    systemd.timers.wake-maintenance = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 03:00";
        WakeSystem = true; # from suspend; a powered-off host skips the week
      };
    };

    ## Upgrade, GC, Optimise, Reboot Into the New Generation
    systemd.services.wake-maintenance = {
      description = "Weekly Maintenance";
      path = [ config.systemd.package ];
      serviceConfig.Type = "oneshot";
      script = ''
        exec systemd-inhibit --what=sleep --who=wake-maintenance --why="Weekly maintenance" ${lib.getExe maintenance}
      '';
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
