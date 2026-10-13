#### Secure Boot (Lanzaboote) ####

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  luksDevices = lib.mapAttrsToList (_: d: d.device) config.boot.initrd.luks.devices;
  encrypted = luksDevices != [ ];
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  assertions = [
    {
      assertion = lib.length luksDevices <= 1;
      message = "secure_boot.nix enrolls the measured boot policy into one LUKS device; this host declares ${toString (lib.length luksDevices)}.";
    }
  ];

  ## Boot (Lanzaboote replaces systemd-boot; UEFI only)
  boot.loader.systemd-boot.enable = lib.mkForce false;

  ## Keys generated on the machine, enrolled on first boot (see installer/README.md)
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys = {
      enable = true;
      autoReboot = true;
    };

    ## Measured boot on an encrypted disk: a pcrlock policy the TPM unlock follows across updates
    configurationLimit = lib.mkIf config.boot.lanzaboote.measuredBoot.enable (lib.mkDefault 4); # systemd-pcrlock policy size
    measuredBoot = {
      enable = lib.mkDefault encrypted; # false where `systemd-pcrlock is-supported` is not yes
      pcrs = [
        0
        4
        7
      ];
      autoCryptenroll = {
        enable = lib.mkDefault config.boot.lanzaboote.measuredBoot.enable;
        device = lib.mkIf encrypted (lib.head luksDevices);
      };
    };
  };

  ## Packages
  environment.systemPackages = [ pkgs.sbctl ];
}
