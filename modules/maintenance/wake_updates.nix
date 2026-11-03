#### Wake From Sleep Updates ####

{
  config,
  lib,
  pkgs,
  ...
}:

let
  maintenance = pkgs.writeShellApplication {
    name = "wake-updates";
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
  imports = [ ./generic.nix ];

  ## Weekly Window (the daily upgrade timer stays; GC and optimise move here)
  nix.gc.automatic = false;
  nix.optimise.automatic = false;
  systemd.timers.wake-updates = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 03:00";
      WakeSystem = true; # from suspend; a powered-off host skips the week
    };
  };

  ## Upgrade, GC, Optimise, Reboot Into the New Generation
  systemd.services.wake-updates = {
    description = "Weekly Maintenance";
    path = [ config.systemd.package ];
    serviceConfig.Type = "oneshot";
    script = ''
      exec systemd-inhibit --what=sleep --who=wake-updates --why="Weekly maintenance" ${lib.getExe maintenance}
    '';
  };
}
