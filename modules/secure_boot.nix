#### Secure Boot (Lanzaboote) ####

{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

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
  };

  ## Packages
  environment.systemPackages = [ pkgs.sbctl ];
}
