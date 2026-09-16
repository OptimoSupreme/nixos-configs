#### Btrfs Snapshots ####

{ pkgs, ... }:

{
  ## Create .snapshots subvolume
  systemd.tmpfiles.rules = [ "v /home/.snapshots 0750 root root -" ];

  ## Snapper config
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    SPACE_LIMIT = "0.5";
    FREE_LIMIT = "0.2";
    BACKGROUND_COMPARISON = true;
    NUMBER_CLEANUP = true;
    NUMBER_MIN_AGE = 3600;
    NUMBER_LIMIT = 50;
    NUMBER_LIMIT_IMPORTANT = 10;
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_MIN_AGE = 3600;
    TIMELINE_LIMIT_HOURLY = 2;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_QUARTERLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
    EMPTY_PRE_POST_CLEANUP = true;
    EMPTY_PRE_POST_MIN_AGE = 3600;
  };

  environment.etc."btrfs-assistant.conf".text = ''
    snapper=/run/current-system/sw/bin/snapper
  '';

  ## Packages
  environment.systemPackages = with pkgs; [
    btrfs-assistant
    snapper
  ];
}
