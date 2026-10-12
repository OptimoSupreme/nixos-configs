#### Microfetch ####

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.microfetch ];
  programs.bash.interactiveShellInit = ''
    command -v microfetch >/dev/null && microfetch
  '';
}
