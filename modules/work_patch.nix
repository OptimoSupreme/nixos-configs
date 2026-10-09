#### Work Patch ####

{ lib, pkgs, ... }:

let
  pkcs11Modules = {
    OpenSC = "${pkgs.opensc}/lib/opensc-pkcs11.so";
    "p11-kit-trust" = "${pkgs.p11-kit}/lib/pkcs11/p11-kit-trust.so";
  };
in
{
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

  ## Packages
  environment.systemPackages = with pkgs; [
    ungoogled-chromium
    opensc
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
