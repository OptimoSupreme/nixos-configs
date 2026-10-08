#### Personal Environment ####

{ lib, pkgs, ... }:

let
  user = "justin";
  pkcs11Modules = {
    OpenSC = "${pkgs.opensc}/lib/opensc-pkcs11.so";
    "p11-kit-trust" = "${pkgs.p11-kit}/lib/pkcs11/p11-kit-trust.so";
  };
in
{
  imports = [ ./desktop.nix ];

  ## Networking
  networking.firewall.allowedTCPPorts = [ 53317 ]; # LocalSend
  networking.firewall.allowedUDPPorts = [ 53317 ];

  ## Passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = false;

  ## Containers and VMs
  virtualisation.podman.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ user ];

  ## Git identity
  programs.git = {
    enable = true;
    config = {
      user.name = "Justin Ward";
      user.email = "jward92@gmail.com";
    };
  };

  ## Enable CAC
  services.pcscd.enable = true;
  environment.etc."opensc.conf".source = ../assets/cac/opensc.conf;
  security.pki.certificateFiles = [ ../assets/cac/DoD_PKI_bundle.pem ];

  ## Firefox CAC Config
  programs.firefox.policies.SecurityDevices = pkcs11Modules;

  ## Ungoogled Chromium CAC Config (no Chromium policy exists)
  systemd.user.services.nssdb-pkcs11 = {
    description = "Register PKCS#11 modules in the user NSS database";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = "!@system";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.nss.tools ];
    script = ''
      db="$HOME/.pki/nssdb"
      mkdir -p "$db"
      [ -f "$db/pkcs11.txt" ] || certutil -N -d "sql:$db" --empty-password
      register() {
        modutil -dbdir "sql:$db" -list "$1" 2>/dev/null | grep -qF "$2" && return
        modutil -force -dbdir "sql:$db" -delete "$1" >/dev/null 2>&1 || true
        modutil -force -dbdir "sql:$db" -add "$1" -libfile "$2"
      }
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: file: ''
        register ${name} ${file}
      '') pkcs11Modules
    );
  };

  ## Shim for non-Nix binaries (some Codium extensions)
  programs.nix-ld.enable = true;

  ## Packages
  environment.systemPackages = with pkgs; [
    vscodium
    ungoogled-chromium
    distrobox
    gh
    opensc
  ];

  ## Flatpaks
  systemd.services.flatpak-apps =
    let
      flatpaks = [
        "com.slack.Slack"
        "us.zoom.Zoom"
        "com.discordapp.Discord"
        "org.gnome.Fractal"
        "org.jellyfin.JellyfinDesktop"
        "com.spotify.Client"
        "com.valvesoftware.Steam"
        "com.usebottles.bottles"
        "org.localsend.localsend_app"
        "app.drey.Warp"
        "org.freecad.FreeCAD"
        "org.gimp.GIMP"
      ];
    in
    {
      description = "Install the personal flatpak app set";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig = {
        StartLimitIntervalSec = 3600;
        StartLimitBurst = 120;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      path = [ pkgs.flatpak ];
      script = ''
        flatpak install --system --noninteractive --assumeyes flathub ${lib.escapeShellArgs flatpaks}
      '';
    };

  ## dconf
  programs.dconf.profiles.user.databases = [
    { keyfiles = [ ../assets/dconf/personal_environment ]; }
  ];
}
