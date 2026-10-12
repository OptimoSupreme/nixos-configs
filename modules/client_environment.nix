#### Client Environment ####

{ ... }:

{
  imports = [ ./desktop.nix ];

  ## dconf
  programs.dconf.profiles.user.databases = [
    { keyfiles = [ ../assets/dconf/client_environment ]; }
  ];
}
