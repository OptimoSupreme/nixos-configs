#### Work Patch ####

{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  ## FreeRDP from unstable: 3.32.2 stops a redirected smart card from locking the CAC for every other local app
  freerdp = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.freerdp;
  ## Stable paths: NSS databases keep the registered path, and store paths die on upgrade
  pkcs11Modules = {
    OpenSC = "/run/current-system/sw/lib/pkcs11/opensc-pkcs11.so";
    "p11-kit-trust" = "/run/current-system/sw/lib/pkcs11/p11-kit-trust.so";
  };

  ## DoD roots for Firefox, one file per certificate (Certificates.Install reads one per file)
  dodCerts =
    let
      blocks = lib.drop 1 (
        lib.splitString "-----BEGIN CERTIFICATE-----" (builtins.readFile ../assets/cac/DoD_PKI_bundle.pem)
      );
      body = block: lib.head (lib.splitString "-----END CERTIFICATE-----" block);
    in
    lib.imap0 (
      i: block:
      pkgs.writeText "dod-ca-${toString i}.pem" "-----BEGIN CERTIFICATE-----${body block}-----END CERTIFICATE-----\n"
    ) blocks;

  ## Azure Virtual Desktop (Government cloud; FreeRDP defaults to commercial endpoints)
  # Entra sign-in in the system browser; nixpkgs does not build this helper
  avdAuthHelper = pkgs.stdenvNoCC.mkDerivation {
    pname = "freerdp-xdg-aad-helper";
    inherit (freerdp) version src;
    buildInputs = [ pkgs.python3 ]; # patchShebangs resolves the interpreter from here
    dontConfigure = true;
    dontBuild = true;
    # winpr hands the helper a read-only stdout/stderr when xfreerdp has no terminal; its first print would kill the browser thread
    installPhase = ''
      install -Dm755 client/common/xdg-aad-helper/xdg-aad-helper.py $out/libexec/freerdp-xdg-aad-helper
      install -Dm755 client/common/xdg-aad-helper/freerdp_aad_handler.py $out/libexec/freerdp-aad-handler
      mkdir -p $out/bin
      cat > $out/bin/freerdp-xdg-aad-helper <<EOF
      #!${pkgs.runtimeShell}
      exec >"\''${XDG_RUNTIME_DIR:-/tmp}/freerdp-aad-helper.log" 2>&1
      exec $out/libexec/freerdp-xdg-aad-helper "\$@"
      EOF
      chmod +x $out/bin/freerdp-xdg-aad-helper
    '';
  };
  avdWorkspaces = {
    arizona = "AVD - Arizona";
    virginia = "AVD - Virginia";
  };
  avd = pkgs.writeShellApplication {
    name = "avd";
    runtimeInputs = [
      freerdp
      pkgs.xdg-utils
      pkgs.desktop-file-utils # the helper gives up on registering its URL handler without update-desktop-database
    ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "usage: avd <workspace.rdpw | name> [xfreerdp options...]" >&2
        exit 1
      fi
      rdpw=$1
      shift
      if [ ! -f "$rdpw" ]; then
        shopt -s nullglob nocaseglob
        matches=("$HOME/git/Work/AVD"/*"$rdpw"*.rdpw)
        if [ ''${#matches[@]} -ne 1 ]; then
          echo "avd: no unique workspace matching '$rdpw' in $HOME/git/Work/AVD" >&2
          exit 1
        fi
        rdpw=''${matches[0]}
      fi
      # cert:ignore: session hosts rotate behind one gateway name, so pinning prompts on stdin, which the launchers lack
      exec xfreerdp "$rdpw" /cert:ignore /smartcard +clipboard \
        /azure:ad:login.microsoftonline.us,tenantid:common,avd-scope:https%3A%2F%2Fwww.wvd.azure.us%2F.default%20openid%20profile%20offline_access,avd-access:https%%3A%%2F%%2Flogin.microsoftonline.com%%2Fcommon%%2Foauth2%%2Fnativeclient,auth-helper:${avdAuthHelper}/bin/freerdp-xdg-aad-helper \
        "$@"
    '';
  };
  avdLaunchers = lib.mapAttrsToList (
    name: title:
    pkgs.makeDesktopItem {
      name = "avd-${name}";
      desktopName = title;
      exec = "${lib.getExe avd} ${name}";
      icon = "computer";
      categories = [
        "Network"
        "RemoteAccess"
      ];
    }
  ) avdWorkspaces;
in
{
  ## Enable CAC
  services.pcscd.enable = true;
  environment.etc."opensc.conf".source = ../assets/cac/opensc.conf;
  security.pki.certificateFiles = [ ../assets/cac/DoD_PKI_bundle.pem ];

  ## Firefox CAC Config (Delete runs first, so Add can replace a stale entry of the same name)
  programs.firefox.policies = {
    SecurityDevices = {
      Add = { inherit (pkcs11Modules) OpenSC; }; # p11-kit-trust at NSS startup breaks every Firefox TLS chain
      Delete = builtins.attrNames pkcs11Modules;
    };
    Certificates.Install = map toString dodCerts;
  };

  ## Chromium CAC Config (no Chromium policy exists)
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
  environment.systemPackages =
    with pkgs;
    [
      chromium
      opensc
      p11-kit.out # the default bin output has no lib/pkcs11
      avd
    ]
    ++ [ freerdp ]
    ++ avdLaunchers;

  ## Flatpaks
  systemd.services.flatpak-apps.script = lib.mkAfter ''
    flatpak install --system --noninteractive --assumeyes flathub com.slack.Slack us.zoom.Zoom
  '';

  ## dconf (work apps on page one, home_patch apps on page two)
  programs.dconf.profiles.user.databases = lib.mkBefore [
    { keyfiles = [ ../assets/dconf/work_patch ]; }
  ];
}

# The Azure Virtual Desktop pieces (freerdp, the auth helper, the avd wrapper and its launchers)
# exist for the Army USIEM project. Remove them once it ends; the CAC browser setup stays.
