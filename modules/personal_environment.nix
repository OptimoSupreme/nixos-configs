#### Personal Environment ####

{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  user = "justin";
in
{
  imports = [
    ./workstation_core.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  ## Passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  ## Containers and VMs
  virtualisation.podman.enable = lib.mkDefault true;
  virtualisation.libvirtd.enable = lib.mkDefault true;
  programs.virt-manager.enable = lib.mkDefault true;
  virtualisation.libvirtd.qemu.swtpm.enable = lib.mkDefault true; # emulated TPM 2.0 for VMs
  users.groups.libvirtd.members = [ user ];

  ## Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    users.${user} = import ../home/justin;
  };

  ## Shim for non-Nix binaries (some Codium extensions)
  programs.nix-ld.enable = lib.mkDefault true;

  ## Packages
  environment.systemPackages = with pkgs; [ distrobox ];

  ## Flatpaks (home_patch and work_patch each add their install line)
  systemd.services.flatpak-apps = {
    description = "Install the flatpak app set";
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
  };

  ## dconf
  programs.dconf.profiles.user.databases = [
    { keyfiles = [ ../assets/dconf/personal_environment ]; }
  ];
}

# home_patch.nix and work_patch.nix layer on this file; a host imports one or both.
# The split exists for the work laptop. Once work_patch.nix is no longer needed (new
# job, retirement), delete it and merge home_patch.nix back into this file.
#
# App grid: ../assets/dconf/personal_environment lays every app out on one page, home
# apps included. ../assets/dconf/work_patch, first in the profile via mkBefore, lays
# out two pages, work then home. GNOME builds icons only for installed apps and
# creates a page only when an icon lands on it, so the two keyfiles cover every case:
#   home_patch only -> personal keyfile: one page, shared and home apps
#   work_patch only -> work keyfile: page two has nothing installed, so one page
#   both            -> work keyfile: work on page one, home on page two
# To add an app, install it in the patch it belongs to and place it in both keyfiles:
# the single page of the personal one, and the matching page of the work one.
