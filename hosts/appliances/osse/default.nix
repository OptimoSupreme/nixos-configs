#### Chartplotter ####

{ config, pkgs, ... }:

let
  # Kiosk payload: session, supervision, first-boot init, persist props,
  # backlight bridge, graceful-stop choreography. The scripts call tools by
  # bare name; each unit's `path` supplies them.
  helm = pkgs.runCommand "helm" { } ''
    mkdir $out
    cp ${./scripts}/*.sh $out/
    chmod +x $out/*.sh
    patchShebangs $out
  '';

  # Waydroid container hostname: waydroid regenerates the container's LXC
  # config from these template snippets (a machine-local edit of the
  # generated config is silently reverted), and lxc.uts.name is what
  # `hostname` returns inside Android — match the host's name. Android's
  # own init.rc `hostname localhost` loses: sethostname fails inside the
  # container, so the LXC value sticks. The grep fails the build loudly if
  # a waydroid update reshapes the templates (only config_3 carries the
  # line today).
  waydroid = pkgs.waydroid.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i 's/^lxc\.uts\.name = waydroid$/lxc.uts.name = ${config.networking.hostName}/' \
        data/configs/config_*
      grep -q '^lxc.uts.name = ${config.networking.hostName}$' data/configs/config_3
    '';
  });

  # The Android system+vendor images (WayDroid-ATV a16-qpr2 channel, GAPPS),
  # baked into the system the way helm baked them into its OS image:
  # /etc/waydroid-extra/images is one of waydroid's preinstalled-image
  # paths, so first boot initializes offline in seconds, OTA stays disabled
  # (`waydroid upgrade` refuses), and nothing downloads at sea. helm's
  # monthly rebuild took whatever the channel served; here the build is
  # pinned and a bump is an edit to these lines — the newest build is the
  # last entry ("filename"; "id" is the zip's sha256) of
  #   https://waydroid-atv.github.io/ota/a16-qpr2/system/lineage/waydroid_x86_64/GAPPS.json
  #   https://waydroid-atv.github.io/ota/a16-qpr2/vendor/waydroid_x86_64/MAINLINE.json
  # The first rebuild that includes them pulls ~1.6 GB into the store.
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
  android-images = pkgs.runCommand "waydroid-atv-images-${android.build}"
    { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir $out
    unzip -j ${android.system} '*system.img' -d $out
    unzip -j ${android.vendor} '*vendor.img' -d $out
    test -f $out/system.img && test -f $out/vendor.img
    # what's baked, for `cat /etc/waydroid-extra/images/helm-manifest.json`
    echo '{ "build": "${android.build}", "system": "${android.system.name}", "vendor": "${android.vendor.name}" }' \
      > $out/helm-manifest.json
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
  # picks the attr matching the hostname. Android reports it too (the
  # container's lxc.uts.name, above).
  networking.hostName = "osse";

  # Boot
  ## UEFI: systemd-boot with a 10-entry menu
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  ## systemd in the initrd; quiet console
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [ "quiet" ];
  ## Straight into the kiosk; hold a key at power-on for the boot menu
  boot.loader.timeout = 0;

  # Kernel: latest stable (pkgs.linuxPackages for the LTS) — helm ran
  # Fedora's current kernel, and a box that isn't bought yet gets the best
  # driver coverage.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # GPU: not chosen yet. No desktop module on this box, so mesa is enabled
  # here rather than in a desktop layer — weston renders on it, and Android
  # gets the render node bind-mounted into the container. What a particular
  # GPU needs on top is a host fact: pick it from templates/workstations, "GPU",
  # once the box exists (AMD: nothing; Intel: intel-media-driver).
  hardware.graphics.enable = true;

  # Non-free firmware blobs: whatever WiFi chip the box has is dead without
  # its firmware, and losing WiFi strands the box (helm carried its lab
  # box's iwlwifi blob by hand; this covers every chip family).
  hardware.enableRedistributableFirmware = true;

  # Appliance basics: UTC clock (a boat crosses time zones; the rest of the
  # fleet keeps America/New_York), and no sleep states at the helm.
  time.timeZone = "UTC";
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
  };

  # Power button = graceful poweroff: logind starts the poweroff, and
  # systemd's reverse-dependency stop order runs helm-kiosk's ExecStop
  # (waydroid session stop) before weston dies and before waydroid-container
  # stops. No display sleep ever — this is a fixed-mount chartplotter.
  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandlePowerKeyLongPress = "poweroff";
    HandleLidSwitch = "ignore";
    IdleAction = "ignore";
  };

  # Networking: NetworkManager with its WiFi stack (helm had to add
  # NetworkManager-wifi + wpa_supplicant by hand — fedora-bootc ships
  # none). No WiFi profile here: the boat's network is joined on the box
  # (`nmcli dev wifi connect <ssid> password <psk>`) and lives in mutable
  # state — README.
  networking.networkmanager.enable = true;

  # mDNS: the box answers at osse.local
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.addresses = true;
  };

  # Don't block boot on the network
  systemd.services.NetworkManager-wait-online.enable = false;

  # Audio: pipewire under the lingering user manager — the waydroid session
  # bind-mounts its pulse socket into the container.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Android: Waydroid — an LXC container on the NixOS kernel's binder. The
  # module brings waydroid-container.service (the container manager; the
  # container itself starts when the kiosk session asks) and lxc.
  virtualisation.waydroid = {
    enable = true;
    package = waydroid;
  };
  environment.etc."waydroid-extra/images".source = android-images;

  # Kiosk: weston (kiosk-shell) under seatd, autolaunching the Waydroid
  # session. A native-1080p panel needs nothing more; one that isn't
  # (helm's lab box had a 4K eDP) needs a real 1080p CRTC mode pinned via a
  # CVT modeline in an [output] block, because kiosk-shell centers a small
  # fullscreen buffer rather than upscaling it and plain `mode=1920x1080`
  # is ignored unless the EDID lists it. Bump cvt's pixel clock to
  # htotal*vtotal*60 so the refresh lands at or above 60.000 Hz — the
  # Waydroid hwcomposer floors it to whole fps and a 59.9x mode judders.
  # Android's own 1080p is helm-props' job, not the compositor's (never
  # scale=2: the hwcomposer would composite at panel x scale).
  services.seatd.enable = true;
  environment.etc."helm/weston.ini".text = ''
    [core]
    shell=kiosk-shell.so
    idle-time=0
    require-input=false

    #[output]
    #name=eDP-1
    #mode=173.108 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync

    [autolaunch]
    path=${helm}/helm-waydroid.sh
  '';

  # The kiosk session. user@1000 is the lingering kiosk user's manager: it
  # provides the session bus and the pipewire/pipewire-pulse sockets the
  # waydroid session requires, and creates /run/user/1000.
  systemd.services.helm-kiosk = {
    description = "Helm kiosk: weston + Waydroid full-screen";
    wantedBy = [ "multi-user.target" ];
    requires = [ "seatd.service" "waydroid-container.service" "user@1000.service" ];
    wants = [ "helm-firstboot.service" ];
    after = [
      "seatd.service"
      "waydroid-container.service"
      "user@1000.service"
      "systemd-user-sessions.service"
      "helm-firstboot.service"
    ];
    path = [ pkgs.weston waydroid pkgs.coreutils pkgs.gnugrep ];
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
    };
    serviceConfig = {
      User = "justin";
      Group = "users";
      ExecStart = "${helm}/helm-session.sh";
      # Graceful order: stop the waydroid session BEFORE weston dies (see
      # helm-kiosk-stop.sh). On poweroff, systemd stops this unit before
      # waydroid-container (reverse dependency order), so the power button
      # gets the same choreography.
      ExecStop = "${helm}/helm-kiosk-stop.sh";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # First boot: initialize Waydroid from the baked images, once, before the
  # container and the kiosk. journal+console so the first-time-setup
  # message reaches the panel.
  systemd.services.helm-firstboot = {
    description = "Helm first boot: initialize the Android runtime from baked images";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/waydroid/waydroid.cfg";
    before = [ "waydroid-container.service" "helm-kiosk.service" ];
    after = [ "local-fs.target" ];
    path = [ waydroid pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${helm}/helm-firstboot.sh";
      StandardOutput = "journal+console";
    };
  };

  # Persist props, every boot. Type=exec, not oneshot: the script waits for
  # the container and Android's property service (minutes on a first boot)
  # and must not hold up the boot.
  systemd.services.helm-props = {
    description = "Helm: enforce Waydroid persist props (true 1080p + no_presentation)";
    wantedBy = [ "multi-user.target" ];
    after = [ "waydroid-container.service" ];
    path = [ pkgs.lxc pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${helm}/helm-props.sh";
    };
  };

  # Backlight bridge: the Android brightness slider drives the host
  # backlight (auto-detected under /sys/class/backlight; a display with no
  # host backlight control needs its own dimming story).
  systemd.services.helm-backlight = {
    description = "Helm backlight: Android brightness slider drives the panel backlight";
    wantedBy = [ "multi-user.target" ];
    after = [ "waydroid-container.service" "helm-kiosk.service" ];
    path = [ pkgs.lxc pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      ExecStart = "${helm}/helm-backlight.sh";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Updates: nothing on the boat updates on its own — a bad update is worse
  # at sea than at the dock (helm's rule; palantir and gollum, at home,
  # switch on a Sunday timer). The fleet's pull service (maintenance.nix)
  # stays wired up with its timer off, so an update is two commands when
  # you choose to: `sudo systemctl start nixos-upgrade.service` stages the
  # new generation, `sudo systemctl reboot` applies it. Roll back from the
  # boot menu (hold a key at power-on).
  systemd.timers.nixos-upgrade.enable = false;

  # Users. Declared, as on palantir: no desktop, so ssh is the way in and
  # sudo the way up — both as justin, by password, set on the box (users
  # are mutable; nothing in the repo). Root has no password and no ssh.
  # justin is also the kiosk user (helm kept a separate
  # locked one): pinned to uid 1000 because the kiosk unit hardcodes
  # /run/user/1000, and lingering — logind then starts user@1000 at every
  # boot, whose manager provides the session dbus and the
  # pipewire/pipewire-pulse sockets the waydroid session hard-requires.
  users.users.justin = {
    isNormalUser = true;
    uid = 1000;
    linger = true;
    # seat: weston under seatd; input/video/render: what helm's kiosk user
    # had; audio: pipewire under a lingering manager has no logind session
    # to hand it the sound devices, so it needs the group
    extraGroups = [ "wheel" "networkmanager" "seat" "input" "video" "render" "audio" ];
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
    weston # weston-screenshooter: panel screenshots over ssh (README)
    lxc # lxc-attach into Android by hand, as helm-props/backlight do
  ];

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

  system.stateVersion = "26.05";
}
