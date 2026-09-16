#### Retro TV launcher ####

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
  # python-xlib: the bridge paints the volume OSD straight onto cage's
  # Xwayland (see bridge/retrotv_osd.py). Staged file by file so a stray
  # __pycache__ in the working tree never lands in the store.
  bridge-python = pkgs.python3.withPackages (p: [ p.xlib ]);
  retrotv-bridge = pkgs.runCommand "retrotv-bridge" { } ''
    mkdir $out
    cp ${./bridge/retrotv-bridge.py} $out/retrotv-bridge.py
    cp ${./bridge/retrotv_osd.py} $out/retrotv_osd.py
  '';
in
{
  imports = [
    ./hardware-configuration.nix

    ## Base (every host)
    ../../../modules/maintenance.nix            # staged upgrades, GC/dedup, trim, scrub, SMART, log caps, flakes
    ## Desktop (a client machine: the Tetra desktop, plus firefox.nix)
    # ../../../modules/general_environment.nix  # GNOME/GDM, app set, Flathub + GNOME Software, extensions, dconf defaults, plymouth
    # ../../../modules/firefox.nix              # policies + autoconfig defaults
    ## Disk (as installed: btrfs_snapshots.nix for a btrfs /home, tpm_decryption.nix for a LUKS-encrypted disk)
    # ../../../modules/btrfs_snapshots.nix      # snapper /home snapshots, btrfs-assistant
    # ../../../modules/tpm_decryption.nix       # tpm2-tools + enable-tpm-decryption (TPM2 auto-unlock enroll)
    ## Mine (instead of general_environment: the Tetra-Tailored desktop)
    # ../../../modules/personal_environment.nix # dev/virt tooling, CAC + DoD roots, LocalSend, personal flatpaks, denser dash-to-panel
    ## Console (instead of the desktop; register with mkHostOn nixpkgs-unstable)
    # ../../../modules/steam-machine.nix        # Jovian-NixOS: Steam's Gaming Mode and the graphics/audio/network it needs
    ../../../modules/fastfetch.nix              # fastfetch on interactive shells
  ];

  # Keep the flake attr in sync with this — `nixos-rebuild --flake <url>`
  # (and the weekly auto-upgrade) picks the attr matching the hostname.
  networking.hostName = "palantir";

  # Time zone
  time.timeZone = "America/New_York";

  # Boot
  ## UEFI: systemd-boot with a 10-entry menu
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  ## systemd in the initrd; quiet console (the "quiet" rides with the video mode below)
  boot.initrd.systemd.enable = true;
  ## Straight into the kiosk; hold a key at power-on for the boot menu
  boot.loader.timeout = 0;

  # Kernel: the LTS (pkgs.linuxPackages_latest for latest stable) — an
  # appliance on 2018 hardware, nothing here wants a newer one.
  boot.kernelPackages = pkgs.linuxPackages;

  # GPU: Intel (UHD 630). No desktop module on this box, so mesa is enabled
  # here rather than in a desktop layer; the iHD driver gives it VA-API.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };
  # Early KMS
  boot.initrd.kernelModules = [ "i915" ];

  # The HDMI→composite adapter scales whatever it's fed down to NTSC 480i,
  # so feed it square-pixel 4:3: 640x480 maps 1:1 onto NTSC's 480 lines
  # (no vertical rescale to smear the text). This parameter covers the
  # boot console; the cage script pins the same mode for the session.
  boot.kernelParams = [ "quiet" "video=HDMI-A-1:640x480@60" ];

  # Non-free firmware blobs — the DW1810 WiFi card (Qualcomm QCA9377,
  # ath10k) is dead without its firmware, and losing WiFi on a rebuild
  # strands the box.
  hardware.enableRedistributableFirmware = true;

  # Networking: NetworkManager. No WiFi profile here — the network is
  # joined once on the box (`nmcli dev wifi connect <ssid> password <psk>`)
  # and the profile lives in /etc/NetworkManager/system-connections,
  # mutable state, so the SSID and passphrase stay out of the repo (README).
  networking.networkmanager.enable = true;

  # mDNS: the box answers at palantir.local
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.addresses = true;
  };

  # Sleep is a person, and so is off. The power key (the remote's power
  # button, or the chassis button) suspends to S3 — a two-second "boot"
  # and single-digit watts — and the remote wakes it back up. Nothing
  # sleeps on its own (IdleAction ignore: the launcher is content, someone
  # may be watching). Real off: the on-screen power button (bridge /power
  # → poweroff) or holding the power key for 5s.
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

  # Wake-from-S3 by the remote: the receiver arms itself for remote wakeup,
  # but the USB root hubs' wakeup gates are off by default and break the
  # chain (receiver → hub → XHCI → ACPI XHC, which is S3-enabled).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1915", ATTR{idProduct}=="1025", ATTR{power/wakeup}="enabled"
  '';

  # The USB remote (a XING WEI 2.4G dongle), its odd buttons rebadged:
  #  - Home sends AC Home (c0223), which nothing catches → a real Home key,
  #    so Chromium's home.js and the bridge's game-stopper both see it
  #  - the three-line menu button sends Application/Compose (70065) → mute,
  #    handled by the bridge's watcher everywhere (games included) with the
  #    green MUTE OSD
  #  - the AI button sends Voice Command (c00cf), which Chromium drops →
  #    F13, which it delivers cleanly; home.js turns F13 into "go to the
  #    games shelf"
  services.udev.extraHwdb = ''
    evdev:input:b0003v1915p1025*
     KEYBOARD_KEY_c0223=home
     KEYBOARD_KEY_70065=mute
     KEYBOARD_KEY_c00cf=f13
  '';

  # The launcher's on-screen power button: the bridge (a system service, so
  # outside any seat session) asks logind to power off, same end state as
  # HandlePowerKey above. Default polkit policy would demand admin auth for
  # a session-less subject; -multiple-sessions covers pressing it while
  # someone is also SSHed in.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (subject.user == "justin" &&
          (action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Don't block boot on the network
  systemd.services.NetworkManager-wait-online.enable = false;

  # Kiosk: autologin on tty1 into Cage running Chromium
  services.cage = {
    enable = true;
    user = "justin";
    program = pkgs.writeShellScript "retrotv-kiosk" ''
      # The adapter's EDID prefers 1280x720; pin the 4:3 mode here because
      # the video= kernel param only holds until the compositor modesets
      ${pkgs.wlr-randr}/bin/wlr-randr --output HDMI-A-1 --mode 640x480 || true
      # Chromium writes _metadata (indexed declarativeNetRequest rules)
      # inside the extension dir, so it can't load one straight from the
      # read-only store ("Internal error while parsing rules"): stage a
      # writable copy.
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
    # The launcher loads its box-local config (local.json) through the
    # bridge on its first page load, so the bridge comes up first.
    after = [ "retrotv-bridge.service" ];
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

  # Launcher site, socket-activated.
  # no-store: store paths have 1970 mtimes, so any caching (even revalidation)
  # serves stale pages forever after a rebuild. The site is tiny and local.
  services.static-web-server = {
    enable = true;
    listen = "127.0.0.1:8787";
    root = retrotv-site;
    configuration = {
      advanced.headers = [
        { source = "**"; headers = { "Cache-Control" = "no-store"; }; }
      ];
    };
  };

  # Games bridge: localhost API the games page calls to list and launch
  # game images with the native emulators — Dolphin for GameCube, PCSX2 for
  # PS2 (EmulatorJS can't handle either — see README). It also hands the
  # launcher the box-local config (local.json → /local.js).
  # Runs as justin so the emulators can attach to cage's session.
  systemd.services.retrotv-bridge = {
    description = "retrotv game launch bridge";
    wantedBy = [ "multi-user.target" ];
    environment = {
      RETROTV_GAMES_DIR = "/var/lib/retrotv/games";
      RETROTV_BIOS_DIR = "/var/lib/retrotv/bios"; # PS2 BIOS .bin lives here
      RETROTV_DOLPHIN = "${pkgs.dolphin-emu}/bin/dolphin-emu";
      RETROTV_PCSX2 = "${pkgs.pcsx2}/bin/pcsx2-qt";
      RETROTV_WPCTL = "${pkgs.wireplumber}/bin/wpctl"; # volume keys
      RETROTV_LOCAL_JSON = "/var/lib/retrotv/local.json"; # box-local site config: Jellyfin, weather (README)
      XDG_RUNTIME_DIR = "/run/user/1000"; # justin, the cage session user
      DISPLAY = ":0"; # cage's lazy Xwayland; the emulators need X (see bridge)
      QT_QPA_PLATFORM = "xcb"; # pin both Qt emulators to XWayland
    };
    serviceConfig = {
      User = "justin";
      ExecStart = "${bridge-python}/bin/python3 ${retrotv-bridge}/retrotv-bridge.py";
      Restart = "always";
      RestartSec = 2;
    };
  };

  # ROM / BIOS locations
  systemd.tmpfiles.rules = [
    "d /var/lib/retrotv 0755 justin users -"
    "d /var/lib/retrotv/games 0755 justin users -"
    "d /var/lib/retrotv/bios 0755 justin users -"
  ];

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  nixpkgs.config.allowUnfree = true;

  # Update switch override
  system.autoUpgrade = {
    operation = "switch";
  };

  # Users. Declared, not the installer-made mutable account of the desktop
  # hosts: this box was installed with nixos-anywhere. Headless, so ssh is
  # the only way in — as justin, by password. The password is not in the
  # repo: users are mutable, so it is set on the box (`passwd`; on a
  # reinstall, before the first reboot — README).
  users.users.justin = {
    isNormalUser = true;
    # input: the bridge watches /dev/input for the Home key to stop a game
    extraGroups = [ "wheel" "networkmanager" "input" ];
  };

  # ssh, always on: the only way in on a headless box (as justin, by
  # password; root can't log in). The desktops start theirs on demand.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    tree
    grim # kiosk screenshots over ssh (WAYLAND_DISPLAY=wayland-0)
  ];

  ## Swap (needs configuring still)
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

  system.stateVersion = "26.05";
}
