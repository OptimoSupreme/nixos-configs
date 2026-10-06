#### General Purpose Environment ####

{ ... }:

{
  imports = [ ./desktop.nix ];

  ## dconf
  programs.dconf.profiles.user.databases = [
    { keyfiles = [ ../assets/dconf/general_environment ]; }
  ];
}
