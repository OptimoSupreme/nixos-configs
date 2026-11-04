#### Sleep Then Shutdown ####

{ pkgs, ... }:

{
  ## Power off a suspend that lasts six hours
  systemd.services.sleep-then-shutdown = {
    description = "Sleep Then Shutdown";
    wantedBy = [ "suspend.target" ];
    before = [ "sleep.target" ];
    unitConfig.StopWhenUnneeded = true; # stops on resume, so preStop is the resume hook
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "sleep-then-shutdown";
    };
    script = ''
      date +%s --date '+6 hours' > /run/sleep-then-shutdown/deadline
      rtcwake --mode no --seconds 21600
    '';
    preStop = ''
      if [ "$(date +%s)" -ge "$(( $(cat /run/sleep-then-shutdown/deadline) - 5 ))" ]; then
        systemctl poweroff
      else
        rtcwake --mode disable # woken by the user, not the alarm
      fi
    '';
  };
}
