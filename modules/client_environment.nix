#### Client Environment ####

{ ... }:

{
  imports = [ ./workstation_core.nix ];

  ## dconf
  programs.dconf.profiles.user.databases = [
    { keyfiles = [ ../assets/dconf/client_environment ]; }
  ];
}
