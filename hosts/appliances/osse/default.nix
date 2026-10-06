#### Chartplotter ####

{ config, pkgs, ... }:

let
  ## Kiosk scripts; each unit's `path` supplies the tools they call by bare name
  helm = pkgs.runCommand "helm" { } ''
    mkdir $out
    cp ${./scripts}/*.sh $out/
    chmod +x $out/*.sh
    patchShebangs $out
  '';

  ## Android reports the host's name: waydroid regenerates the LXC config from these templates
  waydroid = pkgs.waydroid.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i 's/^lxc\.uts\.name = waydroid$/lxc.uts.name = ${config.networking.hostName}/' \
        data/configs/config_*
      grep -q '^lxc.uts.name = ${config.networking.hostName}$' data/configs/config_3
    '';
  });

  ## Pinned WayDroid-ATV images, baked into the system (README "Updates" says where new builds are listed)
  android = rec {
    build = "lineage-23.2-20260717";
    system = pkgs.fetchurl {
      url = "mirror://sourceforge/waydroid-atv/images/system/waydroid_x86_64/${build}-GAPPS-waydroid_x86_64-system.zip";
      hash = "sha256-9kp0by7FBBfrs2OtHaEQTVzHG7Odif8homS1ysrrAGo=";
    };
    vendor = pkgs.fetchurl {
      url = "mirror://sourceforge/waydroid-atv/images/vendor/waydroid_x86_64/${build}-MAINLINE-waydroid_x86_64-vendor.zip";
      hash = "sha256-KN+9DkI9/21cfS404VAR+69IZdp2nZkjuEZW2H6fTTw=";
    };
  };
  android-images =
    pkgs.runCommand "waydroid-atv-images-${android.build}" { nativeBuildInputs = [ pkgs.unzip ]; }
      ''
        mkdir $out
        unzip -j ${android.system} '*system.img' -d $out
        unzip -j ${android.vendor} '*vendor.img' -d $out
        test -f $out/system.img && test -f $out/vendor.img
        echo '{ "build": "${android.build}", "system": "${android.system.name}", "vendor": "${android.vendor.name}" }' \
          > $out/helm-manifest.json
      '';
in
{
  imports = [
    ./hardware-configuration.nix

    ## Select Modules
    ../../../modules/maintenance.nix
    ../../../modules/appliance.nix
    ../../../modules/fastfetch.nix
  ];

  ## GPU: not chosen yet (mesa only; add the GPU's extras from template.nix once the box exists)
  hardware.graphics.enable = true;

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## Swap (needs configuring)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 1;
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 8 * 1024;
      priority = 0;
    }
  ];

  ## Networking (WiFi is joined on the box, see README)
  networking = {
    networkmanager.enable = true;
    hostName = "osse";
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  ## mDNS
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.addresses = true;
  };

  ## Timezone (a boat crosses time zones)
  time.timeZone = "UTC";

  ## User Account (uid 1000 and linger: the kiosk units hardcode /run/user/1000 and need user@1000's bus and pipewire sockets)
  users.users.justin = {
    isNormalUser = true;
    uid = 1000;
    linger = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "seat"
      "input"
      "video"
      "render"
      "audio"
    ];
  };

  ## Power: never sleep, power button is a graceful poweroff
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
  };
  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandlePowerKeyLongPress = "poweroff";
    HandleLidSwitch = "ignore";
    IdleAction = "ignore";
  };

  ## Android (Waydroid)
  virtualisation.waydroid = {
    enable = true;
    package = waydroid;
  };
  environment.etc."waydroid-extra/images".source = android-images;

  ## Kiosk: weston kiosk-shell under seatd, autolaunching the Waydroid session
  services.seatd.enable = true;
  environment.etc."helm/weston.ini".text = ''
    [core]
    shell=kiosk-shell.so
    idle-time=0
    require-input=false

    # Non-1080p panels need a pinned mode; see README "Hardware profile"
    #[output]
    #name=eDP-1
    #mode=173.108 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync

    [autolaunch]
    path=${helm}/helm-waydroid.sh
  '';

  ## Kiosk Session
  systemd.services.helm-kiosk = {
    description = "Helm kiosk: weston + Waydroid full-screen";
    wantedBy = [ "multi-user.target" ];
    requires = [
      "seatd.service"
      "waydroid-container.service"
      "user@1000.service"
    ];
    wants = [ "helm-firstboot.service" ];
    after = [
      "seatd.service"
      "waydroid-container.service"
      "user@1000.service"
      "systemd-user-sessions.service"
      "helm-firstboot.service"
    ];
    path = [
      pkgs.weston
      waydroid
      pkgs.coreutils
      pkgs.gnugrep
    ];
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
    };
    serviceConfig = {
      User = "justin";
      Group = "users";
      ExecStart = "${helm}/helm-session.sh";
      ExecStop = "${helm}/helm-kiosk-stop.sh"; # stops the Waydroid session before weston dies
      Restart = "always";
      RestartSec = 3;
    };
  };

  ## First Boot: initialize Waydroid from the baked images
  systemd.services.helm-firstboot = {
    description = "Helm first boot: initialize the Android runtime from baked images";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/waydroid/waydroid.cfg";
    before = [
      "waydroid-container.service"
      "helm-kiosk.service"
    ];
    after = [ "local-fs.target" ];
    path = [
      waydroid
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${helm}/helm-firstboot.sh";
      StandardOutput = "journal+console";
    };
  };

  ## Persist Props (Type=exec: waits minutes for Android on first boot, must not hold up boot)
  systemd.services.helm-props = {
    description = "Helm: enforce Waydroid persist props (true 1080p + no_presentation)";
    wantedBy = [ "multi-user.target" ];
    after = [ "waydroid-container.service" ];
    path = [
      pkgs.lxc
      pkgs.coreutils
      pkgs.gnugrep
    ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${helm}/helm-props.sh";
    };
  };

  ## Backlight Bridge
  systemd.services.helm-backlight = {
    description = "Helm backlight: Android brightness slider drives the panel backlight";
    wantedBy = [ "multi-user.target" ];
    after = [
      "waydroid-container.service"
      "helm-kiosk.service"
    ];
    path = [
      pkgs.lxc
      pkgs.coreutils
      pkgs.gnugrep
    ];
    serviceConfig = {
      ExecStart = "${helm}/helm-backlight.sh";
      Restart = "always";
      RestartSec = 5;
    };
  };

  ## Updates: manual only, a bad update is worse at sea (README "Updates")
  systemd.timers.nixos-upgrade.enable = false;

  ## Packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    tree
    weston # weston-screenshooter over ssh
    lxc # lxc-attach into Android by hand
  ];

  system.stateVersion = "26.05";
}
