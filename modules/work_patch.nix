#### Work Patch ####

{ lib, pkgs, ... }:

let
  ## Stable paths: NSS databases keep the registered path, and store paths die on upgrade
  pkcs11Modules = {
    OpenSC = "/run/current-system/sw/lib/pkcs11/opensc-pkcs11.so";
    "p11-kit-trust" = "/run/current-system/sw/lib/pkcs11/p11-kit-trust.so";
  };
in
{
  ## Enable CAC
  services.pcscd.enable = true;
  environment.etc."opensc.conf".source = ../assets/cac/opensc.conf;
  security.pki.certificateFiles = [ ../assets/cac/DoD_PKI_bundle.pem ];

  ## Firefox CAC Config (Delete runs first, so Add can replace a stale entry of the same name)
  programs.firefox.policies.SecurityDevices = {
    Add = pkcs11Modules;
    Delete = builtins.attrNames pkcs11Modules;
  };

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

  ## Default browser (Chromium's desktop entry otherwise wins the MIME lookup)
  xdg.mime.defaultApplications = lib.genAttrs [
    "text/html"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ] (_: lib.mkDefault "firefox.desktop");

  ## Packages
  environment.systemPackages = with pkgs; [
    ungoogled-chromium
    opensc
    p11-kit.out # the default bin output has no lib/pkcs11
  ];

  ## Flatpaks (appended to the personal_environment install set)
  systemd.services.flatpak-apps.script = lib.mkAfter ''
    flatpak install --system --noninteractive --assumeyes flathub com.slack.Slack us.zoom.Zoom
  '';

  ## dconf (work apps on the first app grid page)
  programs.dconf.profiles.user.databases = lib.mkBefore [
    { keyfiles = [ ../assets/dconf/work_patch ]; }
  ];
}
