#### Retro TV Launcher ####

{ lib, pkgs, ... }:

let
  retrotv-site = pkgs.runCommand "retrotv-site" { } ''
    mkdir $out
    cp -r ${./site}/. $out/
  '';
  retrotv-extension = pkgs.runCommand "retrotv-extension" { } ''
    mkdir $out
    cp -r ${./extension}/. $out/
  '';
  bridge-python = pkgs.python3.withPackages (p: [ p.xlib ]); # the OSD paints onto cage's Xwayland
  retrotv-bridge = pkgs.runCommand "retrotv-bridge" { } ''
    mkdir $out
    cp ${./bridge/retrotv-bridge.py} $out/retrotv-bridge.py
    cp ${./bridge/retrotv_osd.py} $out/retrotv_osd.py
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

  ## GPU: Intel UHD 630
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };
  boot.initrd.kernelModules = [ "i915" ];

  ## Remote: let the USB chain wake the box from S3, rebadge the odd buttons
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1915", ATTR{idProduct}=="1025", ATTR{power/wakeup}="enabled"
  '';
  services.udev.extraHwdb = ''
    evdev:input:b0003v1915p1025*
     KEYBOARD_KEY_c0223=home
     KEYBOARD_KEY_70065=mute
     KEYBOARD_KEY_c00cf=f13
  '';

  ## Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [ "video=HDMI-A-1:640x480@60" ]; # 1:1 onto NTSC's 480 lines, see README "CRT / display notes"

  ## Kernel
  boot.kernelPackages = pkgs.linuxPackages; # LTS

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
    hostName = "palantir";
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  ## mDNS
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.addresses = true;
  };

  ## Timezone
  time.timeZone = "America/New_York";

  ## User Account (input group: the bridge watches /dev/input for the Home key)
  users.users.justin = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "input"
    ];
  };

  ## Power: power key suspends to S3, the remote wakes it, nothing sleeps on its own
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = true;
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
  };

  ## Kiosk: Cage running Chromium on tty1
  nixpkgs.config.allowUnfree = true;
  services.cage = {
    enable = true;
    user = "justin";
    program = pkgs.writeShellScript "retrotv-kiosk" ''
      # The adapter's EDID prefers 1280x720; the video= param only holds until the compositor modesets
      ${pkgs.wlr-randr}/bin/wlr-randr --output HDMI-A-1 --mode 640x480 || true
      # Chromium writes _metadata inside the extension dir, so it needs a writable copy
      EXTDIR="$HOME/.cache/retrotv-extension"
      rm -rf "$EXTDIR"
      mkdir -p "$EXTDIR"
      cp -r ${retrotv-extension}/. "$EXTDIR"/
      chmod -R u+w "$EXTDIR"
      exec ${pkgs.chromium}/bin/chromium \
        --ozone-platform=wayland \
        --kiosk --app=http://127.0.0.1:8787 \
        --remote-debugging-port=9222 \
        --no-first-run \
        --noerrdialogs \
        --disable-session-crashed-bubble \
        --hide-scrollbars \
        --autoplay-policy=no-user-gesture-required \
        --load-extension="$EXTDIR"
    '';
  };
  systemd.services.cage-tty1 = {
    serviceConfig.Restart = lib.mkForce "always";
    after = [ "retrotv-bridge.service" ]; # the launcher loads local.json through the bridge on first paint
    wants = [ "retrotv-bridge.service" ];
  };
  programs.chromium = {
    enable = true;
    extraOpts = {
      PasswordManagerEnabled = false;
      PasswordLeakDetectionEnabled = false;
      DefaultNotificationsSetting = 2; # 2 = block without asking
      DefaultGeolocationSetting = 2;
      DefaultSensorsSetting = 2;
      DefaultWebBluetoothGuardSetting = 2;
      DefaultWebUsbGuardSetting = 2;
      DefaultSerialGuardSetting = 2;
      DefaultWebHidGuardSetting = 2;
      DefaultFileSystemReadGuardSetting = 2;
      DefaultFileSystemWriteGuardSetting = 2;
      DefaultLocalFontsSetting = 2;
      DefaultClipboardSetting = 2;
      AudioCaptureAllowed = false;
      VideoCaptureAllowed = false;
      TranslateEnabled = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      BrowserSignin = 0; # no sign-in prompts
      PromotionalTabsEnabled = false;
      DefaultBrowserSettingEnabled = false;
    };
  };

  ## Launcher Site (no-store: store paths have 1970 mtimes, so any caching serves stale pages forever)
  services.static-web-server = {
    enable = true;
    listen = "127.0.0.1:8787";
    root = retrotv-site;
    configuration = {
      advanced.headers = [
        {
          source = "**";
          headers = {
            "Cache-Control" = "no-store";
          };
        }
      ];
    };
  };

  ## Games Bridge: localhost API that launches the native emulators (README "Games")
  systemd.services.retrotv-bridge = {
    description = "retrotv game launch bridge";
    wantedBy = [ "multi-user.target" ];
    environment = {
      RETROTV_GAMES_DIR = "/var/lib/retrotv/games";
      RETROTV_BIOS_DIR = "/var/lib/retrotv/bios";
      RETROTV_DOLPHIN = "${pkgs.dolphin-emu}/bin/dolphin-emu";
      RETROTV_PCSX2 = "${pkgs.pcsx2}/bin/pcsx2-qt";
      RETROTV_WPCTL = "${pkgs.wireplumber}/bin/wpctl";
      RETROTV_LOCAL_JSON = "/var/lib/retrotv/local.json";
      XDG_RUNTIME_DIR = "/run/user/1000";
      DISPLAY = ":0"; # the emulators need X; cage spawns Xwayland lazily
      QT_QPA_PLATFORM = "xcb";
    };
    serviceConfig = {
      User = "justin";
      ExecStart = "${bridge-python}/bin/python3 ${retrotv-bridge}/retrotv-bridge.py";
      Restart = "always";
      RestartSec = 2;
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/retrotv 0755 justin users -"
    "d /var/lib/retrotv/games 0755 justin users -"
    "d /var/lib/retrotv/bios 0755 justin users -"
  ];

  ## On-screen power button: the session-less bridge may ask logind to power off
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (subject.user == "justin" &&
          (action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions")) {
        return polkit.Result.YES;
      }
    });
  '';

  ## Updates: apply on the spot, nobody is around to reboot
  system.autoUpgrade.operation = "switch";

  ## Packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    tree
    grim # kiosk screenshots over ssh (WAYLAND_DISPLAY=wayland-0)
  ];

  system.stateVersion = "26.05";
}
