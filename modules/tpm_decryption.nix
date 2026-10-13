#### TPM Disk Decryption ####

{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  luksDevices = lib.mapAttrsToList (_: d: d.device) config.boot.initrd.luks.devices;
  measured = (options.boot ? lanzaboote) && config.boot.lanzaboote.measuredBoot.enable;
  policy = config.boot.lanzaboote.measuredBoot.pcrlockPolicy;

  tpmEnroll = pkgs.writeShellApplication {
    name = "enable-tpm-decryption";
    runtimeInputs = [ config.systemd.package ];
    text = ''
      if [ "$EUID" -ne 0 ]; then
        echo "Please run as root (sudo enable-tpm-decryption)" >&2
        exit 1
      fi
    ''
    + lib.optionalString measured ''
      if [ ! -f ${policy} ]; then
        echo "No pcrlock policy at ${policy}: reboot into the measured boot generation first" >&2
        exit 1
      fi
    ''
    + lib.concatMapStringsSep "\n" (
      dev:
      if measured then
        ''
          echo "Enrolling TPM2 unlock (systemd-pcrlock policy) for ${dev}"
          systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrlock=${policy} ${lib.escapeShellArg dev}
        ''
      else
        ''
          echo "Enrolling TPM2 unlock (PCR 7: Secure Boot state) for ${dev}"
          systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 ${lib.escapeShellArg dev}
        ''
    ) luksDevices;
  };
in
{
  ## Unlock every LUKS device from the TPM
  options.boot.initrd.luks.devices = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.crypttabExtraOpts = [ "tpm2-device=auto" ];
      }
    );
  };

  config = {
    assertions = [
      {
        assertion = luksDevices != [ ];
        message = "tpm_decryption.nix is imported but this host declares no boot.initrd.luks.devices: remove it from the host's imports, or declare the encrypted device in hardware-configuration.nix.";
      }
    ];
    ## Packages
    environment.systemPackages = [
      pkgs.tpm2-tools
      tpmEnroll
    ];
  };
}
