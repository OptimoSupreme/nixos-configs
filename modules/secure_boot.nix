#### Secure Boot (Lanzaboote) ####

# Replaces systemd-boot with Lanzaboote's signed systemd-boot; UEFI only.
# Keys are generated on the machine at first boot into /var/lib/sbctl and
# never leave it. The first boot also stages them on the ESP, re-signs
# everything and reboots; systemd-boot then enrolls them (alongside
# Microsoft's) if the firmware is in Setup Mode. See installer/README.md.

{ inputs, lib, pkgs, ... }:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys = {
      enable = true;
      autoReboot = true;
    };
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
